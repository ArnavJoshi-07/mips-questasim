// System test bench for the program suite. Runs one program on the
// pipelined core (mips_top) and on the single-cycle core (mips_single)
// side by side, then checks three things:
//
//   1. Golden model: when both have halted, every register and every data
//      memory word of the pipeline must equal the single-cycle core's, and
//      both must have retired the same number of instructions. The
//      single-cycle core has no hazards to get wrong, so any forwarding,
//      stall or flush bug shows up as a difference.
//   2. Expectations: the "# expect" lines of the program's .asm, which
//      programs/asm.py turns into <name>.expect: registers, memory words and
//      pipeline counters (cycles, stalls, flushes, forwards). These catch a
//      bug the two cores share, and pin the pipeline's performance.
//   3. Functional coverage: every cycle, the pipeline's state is sampled
//      into the coverage bins below. The counts are written to +COV=<file>
//      and merged over all programs by tests/coverage_report.py.
//
// Plusargs:
//   +PROGRAM=<file.hex>  program for both cores (read by imem)    required
//   +DATA=<file.hex>     initial data memory (read by dmem)        optional
//   +EXPECT=<file>       expectations from programs/asm.py         optional
//   +COV=<file>          where to write the coverage counts        optional
//   +TRACE               print the per-cycle pipeline trace
//   +VCD                 dump tb_suite.vcd
//
// The program must end in a j to itself. The pipeline is done when that
// halt reaches WB, the single-cycle core when it fetches it.

module tb;
reg clk, reset;
wire [31:0] pc, instr, gold_pc, gold_instr;

mips_top    dut (clk, reset, pc, instr);
mips_single gold(clk, reset, gold_pc, gold_instr);

integer errors, checks, w, fd, n;
reg running, gold_running, trace;
reg [8*256:1] program, expect_file, cov_file;

// Pipeline counters, numbered as in programs/asm.py (COUNTERS)
localparam NCOUNT = 9;
localparam C_CYCLES = 0, C_RETIRED = 1, C_STALLS = 2, C_BEQ_FLUSH = 3, C_J_FLUSH = 4,
           C_FWD_A_MEM = 5, C_FWD_A_WB = 6, C_FWD_B_MEM = 7, C_FWD_B_WB = 8;
integer count [0:NCOUNT-1];
integer gold_cycles, gold_retired;

// What the testbench believes is in ID, EX, MEM and WB, as in tb_mips_top
reg [31:0] pc_id, pc_ex, pc_mem, pc_wb;
reg [31:0] instr_id, instr_ex, instr_mem, instr_wb;
reg [31:0] addr_wb;                         // address of the store/load now in WB

function [31:0] regval;
    input [4:0] r;
    regval = dut.reg_file_0.dout[32*r +: 32];
endfunction

function [31:0] gold_regval;
    input [4:0] r;
    gold_regval = gold.reg_file_0.dout[32*r +: 32];
endfunction

function [8*5:1] regname;
    input [4:0] r;
    case (r)
        0:  regname = "$zero"; 1:  regname = "$at";
        2:  regname = "$v0";   3:  regname = "$v1";
        4:  regname = "$a0";   5:  regname = "$a1";   6:  regname = "$a2";   7:  regname = "$a3";
        8:  regname = "$t0";   9:  regname = "$t1";   10: regname = "$t2";   11: regname = "$t3";
        12: regname = "$t4";   13: regname = "$t5";   14: regname = "$t6";   15: regname = "$t7";
        16: regname = "$s0";   17: regname = "$s1";   18: regname = "$s2";   19: regname = "$s3";
        20: regname = "$s4";   21: regname = "$s5";   22: regname = "$s6";   23: regname = "$s7";
        24: regname = "$t8";   25: regname = "$t9";   26: regname = "$k0";   27: regname = "$k1";
        28: regname = "$gp";   29: regname = "$sp";   30: regname = "$fp";   default: regname = "$ra";
    endcase
endfunction

function [8*12:1] counter_name;
    input integer c;
    case (c)
        C_CYCLES:    counter_name = "cycles";
        C_RETIRED:   counter_name = "retired";
        C_STALLS:    counter_name = "stalls";
        C_BEQ_FLUSH: counter_name = "beq_flushes";
        C_J_FLUSH:   counter_name = "j_flushes";
        C_FWD_A_MEM: counter_name = "fwd_a_mem";
        C_FWD_A_WB:  counter_name = "fwd_a_wb";
        C_FWD_B_MEM: counter_name = "fwd_b_mem";
        default:     counter_name = "fwd_b_wb";
    endcase
endfunction

function [8*4:1] mnemonic;
    input [31:0] i;
    if (i == 32'h0) mnemonic = "nop";
    else case (i[31:26])
        6'b000000: case (i[5:0])
                       6'h20: mnemonic = "add";  6'h22: mnemonic = "sub";
                       6'h24: mnemonic = "and";  6'h25: mnemonic = "or";
                       6'h2a: mnemonic = "slt";  default: mnemonic = "r?";
                   endcase
        6'b001000: mnemonic = "addi";
        6'b100011: mnemonic = "lw";
        6'b101011: mnemonic = "sw";
        6'b000100: mnemonic = "beq";
        6'b000010: mnemonic = "j";
        default:   mnemonic = "?";
    endcase
endfunction

function is_halt;
    input [31:0] p, i;
    is_halt = (i[31:26] == 6'b000010) && ({p[31:28], i[25:0], 2'b00} == p);
endfunction

// Instruction classes, from the instruction word
function is_r;    input [31:0] i; is_r    = i != 0 && i[31:26] == 6'b000000; endfunction
function is_addi; input [31:0] i; is_addi = i[31:26] == 6'b001000; endfunction
function is_lw;   input [31:0] i; is_lw   = i[31:26] == 6'b100011; endfunction
function is_sw;   input [31:0] i; is_sw   = i[31:26] == 6'b101011; endfunction
function is_beq;  input [31:0] i; is_beq  = i[31:26] == 6'b000100; endfunction
function is_j;    input [31:0] i; is_j    = i[31:26] == 6'b000010; endfunction
function is_funct;
    input [31:0] i; input [5:0] f;
    is_funct = is_r(i) && i[5:0] == f;
endfunction
// rt is read (not written) by R-type, sw and beq
function reads_rt;
    input [31:0] i;
    reads_rt = is_r(i) || is_sw(i) || is_beq(i);
endfunction

task check;
    input [31:0] got, want;
    input [8*40:1] what;
begin
    checks = checks + 1;
    if (got !== want) begin
        $display("FAIL: %0s: got %0d (%h), expected %0d (%h)", what, got, got, want, want);
        errors = errors + 1;
    end
end
endtask


// ------------------------------------------------------------ coverage bins
// Each bin counts the cycles in which its condition held. A bin is covered
// once some program in the suite hits it. Names group into areas: the
// report sorts by name, so keep the prefixes.
localparam NBIN = 46;
integer cov [0:NBIN-1];

function [8*32:1] bin_name;
    input integer b;
    case (b)
        0:  bin_name = "instr.add";
        1:  bin_name = "instr.sub";
        2:  bin_name = "instr.and";
        3:  bin_name = "instr.or";
        4:  bin_name = "instr.slt";
        5:  bin_name = "instr.addi";
        6:  bin_name = "instr.lw";
        7:  bin_name = "instr.sw";
        8:  bin_name = "instr.beq";
        9:  bin_name = "instr.j";
        10: bin_name = "instr.nop";
        11: bin_name = "alu.result_zero";
        12: bin_name = "alu.result_negative";
        13: bin_name = "alu.overflow_wraps";
        14: bin_name = "alu.slt_true";
        15: bin_name = "alu.slt_false";
        16: bin_name = "alu.slt_overflow";
        17: bin_name = "fwd.a_from_ex_mem";
        18: bin_name = "fwd.a_from_mem_wb";
        19: bin_name = "fwd.b_from_ex_mem";
        20: bin_name = "fwd.b_from_mem_wb";
        21: bin_name = "fwd.both_operands";
        22: bin_name = "fwd.double_hazard_a";
        23: bin_name = "fwd.double_hazard_b";
        24: bin_name = "fwd.store_data";
        25: bin_name = "fwd.branch_operand";
        26: bin_name = "fwd.load_result";
        27: bin_name = "fwd.zero_not_forwarded";
        28: bin_name = "fwd.regfile_write_then_read";
        29: bin_name = "stall.on_rs";
        30: bin_name = "stall.on_rt";
        31: bin_name = "stall.alu_consumer";
        32: bin_name = "stall.lw_consumer";
        33: bin_name = "stall.sw_consumer";
        34: bin_name = "stall.beq_consumer";
        35: bin_name = "stall.j_held";
        36: bin_name = "stall.lw_zero_no_stall";
        37: bin_name = "flush.beq_taken";
        38: bin_name = "flush.beq_not_taken";
        39: bin_name = "flush.j";
        40: bin_name = "flush.beq_squashes_j";
        41: bin_name = "flush.back_to_back_beq";
        42: bin_name = "mem.negative_offset";
        43: bin_name = "mem.load_after_store";
        44: bin_name = "mem.address_wraps";
        default: bin_name = "reg.write_to_zero";
    endcase
endfunction

// Hit bin b when cond holds
task hit;
    input integer b;
    input cond;
    if (cond) cov[b] = cov[b] + 1;
endtask

// Sampled at the rising edge that ends each cycle, before anything moves.
// The instruction words come from the testbench's own copy of the pipeline
// (instr_ex etc.), the datapath values from the DUT.
task sample_coverage;
    reg [4:0] rs_id, rt_id;
    reg r_ex, alu_ex, slt_ex;
    reg [31:0] a_ex, b_ex;
begin
    rs_id  = instr_id[25:21];
    rt_id  = instr_id[20:16];
    r_ex   = is_r(instr_ex);
    alu_ex = r_ex || is_addi(instr_ex);
    slt_ex = is_funct(instr_ex, 6'h2a);
    a_ex   = dut.alu_a_ex;
    b_ex   = dut.alu_b_ex;

    // Instruction in EX (each program instruction passes EX once)
    hit(0,  is_funct(instr_ex, 6'h20));
    hit(1,  is_funct(instr_ex, 6'h22));
    hit(2,  is_funct(instr_ex, 6'h24));
    hit(3,  is_funct(instr_ex, 6'h25));
    hit(4,  slt_ex);
    hit(5,  is_addi(instr_ex));
    hit(6,  is_lw(instr_ex));
    hit(7,  is_sw(instr_ex));
    hit(8,  is_beq(instr_ex));
    hit(9,  is_j(instr_ex));
    hit(10, instr_ex == 0 && pc_ex != 0);   // a program nop, not a bubble

    // ALU results
    hit(11, alu_ex && !slt_ex && dut.alu_result_ex == 0);
    hit(12, alu_ex && !slt_ex && dut.alu_result_ex[31]);
    hit(13, (is_funct(instr_ex, 6'h20) || is_funct(instr_ex, 6'h22) || is_addi(instr_ex))
            && dut.overflow_ex);
    hit(14, slt_ex && dut.alu_result_ex == 1);
    hit(15, slt_ex && dut.alu_result_ex == 0);
    hit(16, slt_ex && dut.overflow_ex);     // a - b overflows; slt must still be right

    // Forwarding. B only counts when rt is a source: an addi or lw also
    // matches on rt (its destination), but alu_src then picks the immediate.
    hit(17, instr_ex != 0 && dut.forward_a_ex == 2'b10);
    hit(18, instr_ex != 0 && dut.forward_a_ex == 2'b01);
    hit(19, reads_rt(instr_ex) && dut.forward_b_ex == 2'b10);
    hit(20, reads_rt(instr_ex) && dut.forward_b_ex == 2'b01);
    hit(21, reads_rt(instr_ex) && dut.forward_a_ex != 0 && dut.forward_b_ex != 0);
    // Both EX/MEM and MEM/WB write the source register: the newer must win
    hit(22, instr_ex != 0 && dut.forward_a_ex == 2'b10 && dut.reg_write_wb
            && dut.write_reg_wb == dut.rs_ex);
    hit(23, reads_rt(instr_ex) && dut.forward_b_ex == 2'b10 && dut.reg_write_wb
            && dut.write_reg_wb == dut.rt_ex);
    hit(24, is_sw(instr_ex) && dut.forward_b_ex != 0);
    hit(25, is_beq(instr_ex) && (dut.forward_a_ex != 0 || dut.forward_b_ex != 0));
    hit(26, dut.mem_to_reg_wb && ((dut.forward_a_ex == 2'b01 && instr_ex != 0) ||
                                   (dut.forward_b_ex == 2'b01 && reads_rt(instr_ex))));
    // EX/MEM "writes" $zero (a nop, or an instruction with $zero as its
    // destination) while EX reads $zero: nothing may be forwarded
    hit(27, instr_ex != 0 && dut.reg_write_mem && dut.write_reg_mem == 0
            && (dut.rs_ex == 0 || (reads_rt(instr_ex) && dut.rt_ex == 0)));
    // WB writes a register that ID reads in the same cycle: the register file
    // writes on the falling edge, so ID reads the new value (no forwarding)
    hit(28, instr_id != 0 && !is_j(instr_id) && dut.reg_write_wb && dut.write_reg_wb != 0
            && (rs_id == dut.write_reg_wb || (reads_rt(instr_id) && rt_id == dut.write_reg_wb)));

    // Load-use stalls, by which operand and which consumer
    hit(29, dut.stall && rs_id == dut.rt_ex);
    hit(30, dut.stall && rt_id == dut.rt_ex);
    hit(31, dut.stall && (is_r(instr_id) || is_addi(instr_id)));
    hit(32, dut.stall && is_lw(instr_id));
    hit(33, dut.stall && is_sw(instr_id));
    hit(34, dut.stall && is_beq(instr_id));
    hit(35, dut.stall && is_j(instr_id));   // the j waits instead of flushing
    // A lw to $zero followed by a reader of $zero: no stall
    hit(36, is_lw(instr_ex) && instr_ex[20:16] == 0 && instr_id != 0
            && (rs_id == 0 || rt_id == 0) && !dut.stall);

    // Control flow
    hit(37, dut.pc_src_ex);
    hit(38, is_beq(instr_ex) && !dut.pc_src_ex);
    hit(39, dut.jump_flush && !dut.pc_src_ex);
    hit(40, dut.pc_src_ex && dut.jump_id);  // older beq wins over the j in ID
    hit(41, dut.pc_src_ex && is_beq(instr_id));

    // Memory
    hit(42, (is_lw(instr_ex) || is_sw(instr_ex)) && instr_ex[15]);
    hit(43, is_lw(instr_mem) && is_sw(instr_wb) && dut.alu_result_mem[9:2] == addr_wb[9:2]);
    hit(44, (is_lw(instr_mem) || is_sw(instr_mem)) && dut.alu_result_mem[31:10] != 0);

    // A real instruction (not a nop or bubble) writes $zero: it must stay 0
    hit(45, instr_wb != 0 && dut.reg_write_wb && dut.write_reg_wb == 0);
end
endtask


// ------------------------------------------------------------ clock, reset
initial clk = 1'b1;
always #5 clk = ~clk;

initial
    if ($test$plusargs("VCD")) begin
        $dumpfile("tb_suite.vcd");
        $dumpvars(0, tb);
    end


// ------------------------------------------------------------ single-cycle
always @(posedge clk)
    if (gold_running) begin
        if (is_halt(gold_pc, gold_instr))
            gold_running = 1'b0;
        else begin
            gold_cycles = gold_cycles + 1;
            if (gold_instr != 0) gold_retired = gold_retired + 1;
        end
    end


// ------------------------------------------------------------ pipeline
always @(posedge clk)
    if (running) begin
        if (is_halt(pc_wb, instr_wb)) begin
            running = 1'b0;
            if (trace) $display("cycle=%3d halt reached WB", count[C_CYCLES] + 1);
        end else begin
            count[C_CYCLES] = count[C_CYCLES] + 1;
            if (instr_wb != 32'h0) count[C_RETIRED] = count[C_RETIRED] + 1;
            count[C_STALLS]      = count[C_STALLS] + dut.stall;
            count[C_BEQ_FLUSH]   = count[C_BEQ_FLUSH] + dut.pc_src_ex;
            count[C_J_FLUSH]     = count[C_J_FLUSH] + (dut.jump_flush & ~dut.pc_src_ex);
            count[C_FWD_A_MEM]   = count[C_FWD_A_MEM] + (dut.forward_a_ex == 2'b10);
            count[C_FWD_A_WB]    = count[C_FWD_A_WB]  + (dut.forward_a_ex == 2'b01);
            count[C_FWD_B_MEM]   = count[C_FWD_B_MEM] + (dut.forward_b_ex == 2'b10);
            count[C_FWD_B_WB]    = count[C_FWD_B_WB]  + (dut.forward_b_ex == 2'b01);
            sample_coverage;

            if (trace) begin
                $write("cycle=%3d  IF %h:%-4s ID %h:%-4s EX %h:%-4s MEM %h:%-4s WB %h:%-4s",
                       count[C_CYCLES],
                       pc[7:0], mnemonic(instr), pc_id[7:0], mnemonic(instr_id),
                       pc_ex[7:0], mnemonic(instr_ex), pc_mem[7:0], mnemonic(instr_mem),
                       pc_wb[7:0], mnemonic(instr_wb));
                if (dut.reg_write_wb && dut.write_reg_wb != 5'd0)
                    $write("  %0s <= %0d", regname(dut.write_reg_wb), regval(dut.write_reg_wb));
                if (dut.mem_write_mem)
                    $write("  mem[%h] <= %0d", dut.alu_result_mem, dut.write_data_mem);
                if (dut.pc_src_ex)
                    $write("  beq taken -> %h, FLUSH IF/ID+ID/EX", dut.branch_target_ex);
                else if (dut.jump_flush)
                    $write("  j -> %h, FLUSH IF/ID", dut.jump_addr_id);
                if (dut.forward_a_ex == 2'b10) $write("  A<-EX/MEM");
                if (dut.forward_a_ex == 2'b01) $write("  A<-MEM/WB");
                if (dut.forward_b_ex == 2'b10) $write("  B<-EX/MEM");
                if (dut.forward_b_ex == 2'b01) $write("  B<-MEM/WB");
                if (dut.stall)                 $write("  STALL (load-use)");
                $write("\n");
            end
        end

        // Move the instructions along, as the pipeline registers do at this edge
        pc_wb = pc_mem;  instr_wb = instr_mem;  addr_wb = dut.alu_result_mem;
        pc_mem = pc_ex;  instr_mem = instr_ex;
        if (dut.flush_id_ex) begin
            pc_ex = 32'h0; instr_ex = 32'h0;
        end else begin
            pc_ex = pc_id; instr_ex = instr_id;
        end
        if (dut.flush_if_id) begin
            pc_id = 32'h0; instr_id = 32'h0;
        end else if (!dut.stall) begin
            pc_id = pc; instr_id = instr;
        end
    end


// ------------------------------------------------------------ main
reg [8*8:1] kind;
reg [31:0] idx, want;
reg [8*16:1] label;

initial begin
    errors = 0; checks = 0; running = 1'b0; gold_running = 1'b0;
    gold_cycles = 0; gold_retired = 0;
    for (w = 0; w < NCOUNT; w = w + 1) count[w] = 0;
    for (w = 0; w < NBIN; w = w + 1) cov[w] = 0;
    pc_id = 0; pc_ex = 0; pc_mem = 0; pc_wb = 0; addr_wb = 0;
    instr_id = 0; instr_ex = 0; instr_mem = 0; instr_wb = 0;
    trace = $test$plusargs("TRACE");

    if (!$value$plusargs("PROGRAM=%s", program)) begin
        $display("FAIL: tb_suite: no +PROGRAM=<file.hex>");
        $finish;
    end

    // Same reset as tb_mips_top: one falling and one rising edge
    reset = 1'b1;
    #12 reset = 1'b0; running = 1'b1; gold_running = 1'b1;

    w = 0;
    while ((running || gold_running) && w < 5000) begin
        @(posedge clk); w = w + 1;
    end
    #1;

    if (running || gold_running) begin
        $display("FAIL: tb_suite: no halt after %0d cycles (pipeline pc=%h%0s, single-cycle pc=%h%0s)",
                 w, pc, running ? "" : " halted", gold_pc, gold_running ? "" : " halted");
        $finish;
    end

    // 1. Pipeline against the single-cycle core
    for (w = 0; w < 32; w = w + 1)
        if (regval(w) !== gold_regval(w)) begin
            $display("FAIL: %0s: pipeline %0d (%h), single-cycle %0d (%h)",
                     regname(w), regval(w), regval(w), gold_regval(w), gold_regval(w));
            errors = errors + 1;
        end
    for (w = 0; w < 256; w = w + 1)
        if (dut.dmem_0.mem[w] !== gold.dmem_0.mem[w]) begin
            $display("FAIL: dmem word %0d: pipeline %0d (%h), single-cycle %0d (%h)", w,
                     dut.dmem_0.mem[w], dut.dmem_0.mem[w], gold.dmem_0.mem[w], gold.dmem_0.mem[w]);
            errors = errors + 1;
        end
    checks = checks + 32 + 256;
    check(count[C_RETIRED], gold_retired, "retired (pipeline vs single-cycle)");

    // 2. Expectations from the .asm
    if ($value$plusargs("EXPECT=%s", expect_file)) begin
        fd = $fopen(expect_file, "r");
        if (fd == 0) begin
            $display("FAIL: tb_suite: cannot open %0s", expect_file);
            errors = errors + 1;
        end else begin
            n = $fscanf(fd, "%s %d %h %s\n", kind, idx, want, label);
            while (n == 4) begin
                if (kind == "r")      check(regval(idx), want, label);
                else if (kind == "m") check(dut.dmem_0.mem[idx], want, label);
                else                  check(count[idx], want, counter_name(idx));
                n = $fscanf(fd, "%s %d %h %s\n", kind, idx, want, label);
            end
            $fclose(fd);
        end
    end

    // 3. Coverage counts, one "bin count" per line
    if ($value$plusargs("COV=%s", cov_file)) begin
        fd = $fopen(cov_file, "w");
        for (w = 0; w < NBIN; w = w + 1)
            $fdisplay(fd, "%0s %0d", bin_name(w), cov[w]);
        for (w = 0; w < NCOUNT; w = w + 1)
            $fdisplay(fd, "count.%0s %0d", counter_name(w), count[w]);
        $fdisplay(fd, "count.single_cycle_cycles %0d", gold_cycles);
        $fclose(fd);
    end

    $display("cycles=%0d retired=%0d CPI=%0d.%02d (single-cycle: %0d cycles)",
             count[C_CYCLES], count[C_RETIRED],
             count[C_CYCLES] / count[C_RETIRED], (count[C_CYCLES] * 100 / count[C_RETIRED]) % 100,
             gold_cycles);
    $display("stalls=%0d beq_flushes=%0d j_flushes=%0d fwd_a_mem=%0d fwd_a_wb=%0d fwd_b_mem=%0d fwd_b_wb=%0d",
             count[C_STALLS], count[C_BEQ_FLUSH], count[C_J_FLUSH],
             count[C_FWD_A_MEM], count[C_FWD_A_WB], count[C_FWD_B_MEM], count[C_FWD_B_WB]);
    if (errors == 0) $display("PASS: tb_suite %0s (%0d checks)", program, checks);
    else             $display("FAIL: tb_suite %0s (%0d of %0d checks failed)", program, errors, checks);
    $finish;
end
endmodule
