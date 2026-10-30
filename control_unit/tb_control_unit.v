module tb;
reg [5:0] opcode;
wire reg_dst, alu_src, mem_to_reg, reg_write, mem_read, mem_write, branch, jump;
wire [1:0] alu_op;

localparam R_TYPE = 6'b000000, LW = 6'b100011, SW = 6'b101011,
           BEQ    = 6'b000100, ADDI = 6'b001000, J = 6'b000010;

// Expected signals in this order:
// {reg_dst, alu_src, mem_to_reg, reg_write, mem_read, mem_write, branch, jump, alu_op}
wire [9:0] got = {reg_dst, alu_src, mem_to_reg, reg_write, mem_read, mem_write, branch, jump, alu_op};
reg  [9:0] want;
integer errors, checks, n;

control_unit control_unit_0(opcode, reg_dst, alu_src, mem_to_reg, reg_write,
                            mem_read, mem_write, branch, jump, alu_op);

initial begin
    $dumpfile("tb_control_unit.vcd");
    $dumpvars(0, tb);
end

// The truth table from control_unit.v, written as a case statement
task check;
begin
    case (opcode)
        R_TYPE:  want = 10'b1_0_0_1_0_0_0_0_10;
        LW:      want = 10'b0_1_1_1_1_0_0_0_00;
        SW:      want = 10'b0_1_0_0_0_1_0_0_00;
        BEQ:     want = 10'b0_0_0_0_0_0_1_0_01;
        ADDI:    want = 10'b0_1_0_1_0_0_0_0_00;
        J:       want = 10'b0_0_0_0_0_0_0_1_00;
        default: want = 10'b0_0_0_0_0_0_0_0_00;
    endcase

    checks = checks + 1;
    if (got !== want) begin
        $display("FAIL: opcode=%b signals=%b (expected %b)", opcode, got, want);
        errors = errors + 1;
    end
end
endtask

initial begin
    errors = 0; checks = 0;

    // Walkthrough: one row per instruction, then an unsupported opcode
$monitor("time=%0t opcode=%b reg_dst=%b alu_src=%b mem_to_reg=%b reg_write=%b mem_read=%b mem_write=%b branch=%b jump=%b alu_op=%b",
         $time, opcode, reg_dst, alu_src, mem_to_reg, reg_write, mem_read, mem_write, branch, jump, alu_op);
    #0  opcode = R_TYPE;
    #10 check; opcode = LW;
    #10 check; opcode = SW;
    #10 check; opcode = BEQ;
    #10 check; opcode = ADDI;
    #10 check; opcode = J;
    #10 check; opcode = 6'b111111;
    #10 check;
    $monitoroff;

    // Every opcode
    for (n = 0; n < 64; n = n + 1) begin
        opcode = n;
        #1 check;
    end

    if (errors == 0) $display("PASS: tb_control_unit (%0d checks)", checks);
    else             $display("FAIL: tb_control_unit (%0d of %0d checks failed)", errors, checks);
    $finish;
end
endmodule
