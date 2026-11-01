module tb;
reg clk, reset;
wire [31:0] pc, instr;
integer errors, checks, cycles, retired, w;
reg running;

// fibonacci.asm leaves F(0) .. F(11) in dmem words 0..11
reg [31:0] expected [0:11];

mips_single dut(clk, reset, pc, instr);

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
    $dumpfile("tb_mips_single.vcd");
    $dumpvars(0, tb);
end

// The clock starts high so the first edge is falling: reset then covers one
// falling edge (clears reg_file) and one rising edge (clears the PC) before
// it drops at t = 12. The first instruction writes back at the falling edge
// t = 15 and completes at the rising edge t = 20.
initial clk = 1'b1;
always #5 clk = ~clk;

// Per-instruction trace. It samples at the rising edge that ends each
// instruction, before the PC moves on: by then the falling-edge register
// write has happened, so the destination register is read back from the
// register file. d_in and the ALU result are not used here, because they can
// change after the falling edge (see mips_single.v).
// This trace is the walkthrough; a $monitor would also fire on those
// second-half-cycle changes.
always @(posedge clk)
    if (running) begin
        if (instr[31:26] == 6'b000010 && dut.jump_addr == pc) begin
            // j to itself: the program has halted
            running = 1'b0;
            $display("time=%0t pc=%h instr=%h halt", $time, pc, instr);
        end else begin
            cycles = cycles + 1;
            retired = retired + 1;
            if (dut.reg_write)
                $display("time=%0t pc=%h instr=%h %0s <= %0d",
                         $time, pc, instr, regname(dut.write_reg), regval(dut.write_reg));
            else if (dut.mem_write)
                $display("time=%0t pc=%h instr=%h mem[%h] <= %0d",
                         $time, pc, instr, dut.alu_result, dut.read_data_b);
            else
                $display("time=%0t pc=%h instr=%h", $time, pc, instr);
        end
    end

initial begin
    errors = 0; checks = 0; cycles = 0; retired = 0; running = 1'b0;
    expected[0] = 0;  expected[1] = 1;  expected[2]  = 1;  expected[3]  = 2;
    expected[4] = 3;  expected[5] = 5;  expected[6]  = 8;  expected[7]  = 13;
    expected[8] = 21; expected[9] = 34; expected[10] = 55; expected[11] = 89;

    reset = 1'b1;

    // Without +PROGRAM, load fibonacci.hex. Done after time 0 so it lands
    // after imem clears its words.
    #1 if (!$test$plusargs("PROGRAM"))
        $readmemh("../programs/fibonacci.hex", dut.imem_0.mem, 0, 17);

    #11 reset = 1'b0; running = 1'b1;

    // Run until the halt, or give up after ~1000 cycles
    w = 0;
    while (running && w < 1000) begin
        @(posedge clk); w = w + 1;
    end
    #1;

    if (running) begin
        $display("FAIL: tb_mips_single: no halt after %0d cycles (pc=%h)", w, pc);
        $finish;
    end

    // Final state expected after programs/fibonacci.asm
    for (w = 0; w < 12; w = w + 1)
        check(dut.dmem_0.mem[w], expected[w], "dmem word");
    check(regval(2),  89, "$v0");
    check(regval(12), 12, "$t4");
    check(regval(16), 48, "$s0");
    check(retired, 90, "instructions");
    check(cycles, 90, "cycles");

    $display("cycles=%0d instructions=%0d CPI=%0d.%02d",
             cycles, retired, cycles / retired, (cycles * 100 / retired) % 100);

    if (errors == 0) $display("PASS: tb_mips_single (%0d checks)", checks);
    else             $display("FAIL: tb_mips_single (%0d of %0d checks failed)", errors, checks);
    $finish;
end
endmodule
