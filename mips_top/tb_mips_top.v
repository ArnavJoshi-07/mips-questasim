module tb;
reg clk, reset;
wire [31:0] pc, instr;
integer errors, checks, cycles, retired, w;
integer fwd_a_mem, fwd_a_wb, fwd_b_mem, fwd_b_wb, stalls;
integer jump_flushes, branch_flushes;
reg running, default_program;
reg [8*256:1] program;

// Every Fibonacci program leaves F(0) .. F(11) in dmem words 0..11
reg [31:0] expected [0:11];

// What the testbench believes is in ID, EX, MEM and WB (PC and instruction).
// The DUT does not carry the instruction past ID, so the trace follows it
// here, applying the same stalls and flushes as the pipeline registers.
reg [31:0] pc_id, pc_ex, pc_mem, pc_wb;
reg [31:0] instr_id, instr_ex, instr_mem, instr_wb;

mips_top dut(clk, reset, pc, instr);

// Register r as the register file holds it
function [31:0] regval;
    input [4:0] r;
    regval = dut.reg_file_0.dout[32*r +: 32];
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

// Mnemonic of an instruction, for the pipeline trace
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

// j to itself
function is_halt;
    input [31:0] p, i;
    is_halt = (i[31:26] == 6'b000010) && ({p[31:28], i[25:0], 2'b00} == p);
endfunction

task check;
    input [31:0] got, want;
    input [8*24:1] what;
begin
    checks = checks + 1;
    if (got !== want) begin
        $display("FAIL: %0s: got %0d (%h), expected %0d", what, got, got, want);
        errors = errors + 1;
    end
end
endtask

initial begin
    $dumpfile("tb_mips_top.vcd");
    $dumpvars(0, tb);
end

// The clock starts high so the first edge is falling: reset then covers one
// falling edge (clears reg_file) and one rising edge (clears the PC and the
// pipeline registers) before it drops at t = 12.
initial clk = 1'b1;
always #5 clk = ~clk;

// Per-cycle trace, sampled at the rising edge that ends each cycle, before
// the pipeline registers move on. Each column is "PC:instruction" for one
// stage. The register written in WB is read back from the register file,
// which was written at the falling edge half way through the cycle; a store
// shown in MEM is written to dmem at this edge.
//
// The run ends when the halt (j to itself) reaches WB: every instruction
// before it has then completed. cycles counts the cycles up to the one in
// which the last of them was in WB, and retired counts the instructions that
// reached WB, leaving out nops and bubbles.
always @(posedge clk)
    if (running) begin
        if (is_halt(pc_wb, instr_wb)) begin
            running = 1'b0;
            $display("cycle=%3d halt reached WB", cycles + 1);
        end else begin
            cycles = cycles + 1;
            if (instr_wb != 32'h0) retired = retired + 1;

            $write("cycle=%3d  IF %h:%-4s ID %h:%-4s EX %h:%-4s MEM %h:%-4s WB %h:%-4s",
                   cycles,
                   pc[7:0], mnemonic(instr),
                   pc_id[7:0], mnemonic(instr_id),
                   pc_ex[7:0], mnemonic(instr_ex),
                   pc_mem[7:0], mnemonic(instr_mem),
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

            fwd_a_mem = fwd_a_mem + (dut.forward_a_ex == 2'b10);
            fwd_a_wb  = fwd_a_wb  + (dut.forward_a_ex == 2'b01);
            fwd_b_mem = fwd_b_mem + (dut.forward_b_ex == 2'b10);
            fwd_b_wb  = fwd_b_wb  + (dut.forward_b_ex == 2'b01);
            stalls    = stalls    + dut.stall;
            branch_flushes = branch_flushes + dut.pc_src_ex;
            jump_flushes   = jump_flushes + (dut.jump_flush & ~dut.pc_src_ex);
        end

        // Move the instructions along, as the pipeline registers do at this edge
        pc_wb = pc_mem;  instr_wb = instr_mem;
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

initial begin
    errors = 0; checks = 0; cycles = 0; retired = 0; running = 1'b0;
    fwd_a_mem = 0; fwd_a_wb = 0; fwd_b_mem = 0; fwd_b_wb = 0; stalls = 0;
    jump_flushes = 0; branch_flushes = 0;
    pc_id = 0; pc_ex = 0; pc_mem = 0; pc_wb = 0;
    instr_id = 0; instr_ex = 0; instr_mem = 0; instr_wb = 0;
    expected[0] = 0;  expected[1] = 1;  expected[2]  = 1;  expected[3]  = 2;
    expected[4] = 3;  expected[5] = 5;  expected[6]  = 8;  expected[7]  = 13;
    expected[8] = 21; expected[9] = 34; expected[10] = 55; expected[11] = 89;

    reset = 1'b1;

    // Without +PROGRAM, load fibonacci_fwd.hex. Done after time 0 so it
    // lands after imem clears its words.
    default_program = !$value$plusargs("PROGRAM=%s", program);
    #1 if (default_program)
        $readmemh("../programs/fibonacci_fwd.hex", dut.imem_0.mem, 0, 21);

    #11 reset = 1'b0; running = 1'b1;

    // Run until the halt reaches WB, or give up after ~1000 cycles
    w = 0;
    while (running && w < 1000) begin
        @(posedge clk); w = w + 1;
    end
    #1;

    if (running) begin
        $display("FAIL: tb_mips_top: halt did not reach WB after %0d cycles (pc=%h)", w, pc);
        $finish;
    end

    // Final state expected after any of the Fibonacci programs. Each runs
    // the same 90 instructions as fibonacci.asm on the single-cycle core,
    // plus its nops.
    for (w = 0; w < 12; w = w + 1)
        check(dut.dmem_0.mem[w], expected[w], "dmem word");
    check(regval(2),  89, "$v0");
    check(regval(12), 12, "$t4");
    check(regval(16), 48, "$s0");
    check(retired, 90, "instructions");

    // programs/fibonacci_fwd.asm adds 42 nops: 132 instructions through a
    // 5-stage pipeline take 136 cycles. Each forwarding path is used as
    // listed in its header: A<-EX/MEM by the first sw and the first beq,
    // A<-MEM/WB by the second sw and every add, B<-EX/MEM by every
    // sw $t7, B<-MEM/WB by the first beq.
    if (default_program) begin
        check(cycles, 136, "cycles");
        check(fwd_a_mem, 2,  "forwards A<-EX/MEM");
        check(fwd_a_wb,  11, "forwards A<-MEM/WB");
        check(fwd_b_mem, 10, "forwards B<-EX/MEM");
        check(fwd_b_wb,  1,  "forwards B<-MEM/WB");
        check(stalls,    0,  "stalls (the nop covers every load-use)");
    end

    // With flushing, every program runs the same instructions; only the
    // nops it carries change the cycle count. The beq and j delay-slot nops
    // of the older programs are now flushed like any wrong-path instruction.
    // Counts run until the halt reaches WB, so the j count is the 10 loop
    // jumps plus 2 from the halt jumping to itself on the way there.
    if (program == "../programs/fibonacci.hex") begin
        // 90 instructions + 4 to fill the pipeline + 10 load-use stalls
        // + 10 x 1 cycle for the loop j + 2 for the taken exit beq
        check(cycles,         116, "cycles");
        check(stalls,         10,  "stalls");
        check(branch_flushes, 1,   "branch flushes");
        check(jump_flushes,   12,  "jump flushes");
    end

    $display("cycles=%0d instructions=%0d CPI=%0d.%02d",
             cycles, retired, cycles / retired, (cycles * 100 / retired) % 100);
    $display("forwards: A<-EX/MEM %0d, A<-MEM/WB %0d, B<-EX/MEM %0d, B<-MEM/WB %0d",
             fwd_a_mem, fwd_a_wb, fwd_b_mem, fwd_b_wb);
    $display("load-use stalls: %0d", stalls);
    $display("flushes: beq taken %0d (2 cycles each), j %0d (1 cycle each)",
             branch_flushes, jump_flushes);

    if (errors == 0) $display("PASS: tb_mips_top (%0d checks)", checks);
    else             $display("FAIL: tb_mips_top (%0d of %0d checks failed)", errors, checks);
    $finish;
end
endmodule
