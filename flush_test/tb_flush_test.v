// Directed test of branch and jump flushing on mips_top, running
// programs/flush_test.hex (see programs/flush_test.asm for the six cases).
//
// Instructions on a wrong path add to $s7, instructions on the right path
// add 1 to $s6, so a missed flush or a lost instruction shows up in the
// final registers. The trace also lists, per cycle, the stalls and flushes,
// and the testbench checks that each one happens in the expected place:
//   - beq flushes at the taken beqs of cases A, D and F (PC 0c, 3c, 5c);
//   - j flushes at the j of cases C and E (28, 50) and the halt;
//   - load-use stalls at cases D and E (the beq at 3c, the j at 50);
//   - the j at 60 (case F) never flushes on its own: the beq ahead of it
//     wins.

module tb;
reg clk, reset;
wire [31:0] pc, instr;
integer errors, checks, cycles, w;
integer stalls, branch_flushes, jump_flushes, halt_jumps;
reg running;

// What the testbench believes is in ID, EX, MEM and WB, as in tb_mips_top
reg [31:0] pc_id, pc_ex, pc_mem, pc_wb;
reg [31:0] instr_id, instr_ex, instr_mem, instr_wb;

mips_top dut(clk, reset, pc, instr);

function [31:0] regval;
    input [4:0] r;
    regval = dut.reg_file_0.dout[32*r +: 32];
endfunction

function [8*4:1] mnemonic;
    input [31:0] i;
    if (i == 32'h0) mnemonic = "nop";
    else case (i[31:26])
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

task check;
    input [31:0] got, want;
    input [8*40:1] what;
begin
    checks = checks + 1;
    if (got !== want) begin
        $display("FAIL: %0s: got %0d (%h), expected %0d", what, got, got, want);
        errors = errors + 1;
    end
end
endtask

initial begin
    $dumpfile("tb_flush_test.vcd");
    $dumpvars(0, tb);
end

initial clk = 1'b1;
always #5 clk = ~clk;

// Per-cycle trace and checks, sampled at the rising edge that ends each
// cycle. PCs are shown as their low byte: from case E on the PC runs at
// 0x004000xx, the same imem words.
always @(posedge clk)
    if (running) begin
        if (is_halt(pc_wb, instr_wb)) begin
            running = 1'b0;
            $display("cycle=%3d halt reached WB", cycles + 1);
        end else begin
            cycles = cycles + 1;
            $write("cycle=%3d  IF %h:%-4s ID %h:%-4s EX %h:%-4s MEM %h:%-4s WB %h:%-4s",
                   cycles, pc[7:0], mnemonic(instr),
                   pc_id[7:0], mnemonic(instr_id), pc_ex[7:0], mnemonic(instr_ex),
                   pc_mem[7:0], mnemonic(instr_mem), pc_wb[7:0], mnemonic(instr_wb));
            if (dut.stall && dut.jump_id)
                $write("  STALL (load-use on a j: the j waits, no flush)");
            else if (dut.stall)
                $write("  STALL (load-use)");
            if (dut.pc_src_ex)
                $write("  beq taken -> %h, FLUSH IF/ID+ID/EX", dut.branch_target_ex);
            else if (dut.jump_flush)
                $write("  j -> %h, FLUSH IF/ID", dut.jump_addr_id);
            $write("\n");

            if (dut.stall) begin
                stalls = stalls + 1;
                if (pc_id[7:0] != 8'h3c && pc_id[7:0] != 8'h50)
                    check(pc_id[7:0], 8'h3c, "PC of a stalled instruction");
            end
            if (dut.pc_src_ex) begin
                branch_flushes = branch_flushes + 1;
                if (pc_ex[7:0] != 8'h0c && pc_ex[7:0] != 8'h3c && pc_ex[7:0] != 8'h5c)
                    check(pc_ex[7:0], 8'h0c, "PC of a taken beq");
            end else if (dut.jump_flush) begin
                if (pc_id[7:0] == 8'h70) halt_jumps = halt_jumps + 1;
                else begin
                    jump_flushes = jump_flushes + 1;
                    if (pc_id[7:0] != 8'h28 && pc_id[7:0] != 8'h50)
                        check(pc_id[7:0], 8'h28, "PC of a flushing j");
                end
            end
            // Flushing a j out of IF/ID while it is stalled would lose it
            if (dut.stall && dut.flush_if_id)
                check(1, 0, "IF/ID flushed during a stall");
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
    errors = 0; checks = 0; cycles = 0; running = 1'b0;
    stalls = 0; branch_flushes = 0; jump_flushes = 0; halt_jumps = 0;
    pc_id = 0; pc_ex = 0; pc_mem = 0; pc_wb = 0;
    instr_id = 0; instr_ex = 0; instr_mem = 0; instr_wb = 0;

    reset = 1'b1;
    #1 if (!$test$plusargs("PROGRAM"))
        $readmemh("../programs/flush_test.hex", dut.imem_0.mem, 0, 30);
    #11 reset = 1'b0; running = 1'b1;

    w = 0;
    while (running && w < 200) begin
        @(posedge clk); w = w + 1;
    end
    #1;

    if (running) begin
        $display("FAIL: tb_flush_test: halt did not reach WB after %0d cycles (pc=%h)", w, pc);
        $finish;
    end

    check(regval(22), 6, "$s6 (right-path instructions run)");
    check(regval(23), 0, "$s7 (wrong-path instructions run)");
    check(regval(11), 5, "$t3 (case D load)");
    check(regval(16), 5, "$s0 (case E load)");
    check(dut.dmem_0.mem[0], 5, "dmem word 0");
    check(stalls,         2, "load-use stalls (D, E)");
    check(branch_flushes, 3, "beq flushes (A, D, F)");
    check(jump_flushes,   2, "j flushes (C, E)");

    // 18 instructions on the right path before the halt + 4 to fill the
    // pipeline + 2 stalls + 3 x 2 for the taken beqs + 2 x 1 for the j's
    check(cycles, 32, "cycles");

    $display("cycles=%0d  stalls=%0d  beq flushes=%0d  j flushes=%0d (+%0d by the halt)",
             cycles, stalls, branch_flushes, jump_flushes, halt_jumps);
    if (errors == 0) $display("PASS: tb_flush_test (%0d checks)", checks);
    else             $display("FAIL: tb_flush_test (%0d of %0d checks failed)", errors, checks);
    $finish;
end
endmodule
