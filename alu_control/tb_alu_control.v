module tb;
reg [1:0] alu_op;
reg [5:0] funct;
wire [3:0] op;

localparam AND = 4'b0000, OR = 4'b0001, ADD = 4'b0010, SUB = 4'b0110, SLT = 4'b0111;
localparam F_ADD = 6'b100000, F_SUB = 6'b100010, F_AND = 6'b100100,
           F_OR  = 6'b100101, F_SLT = 6'b101010;

reg [5:0] functs [0:4];
reg [3:0] ops [0:4];
integer errors, checks, n;

alu_control alu_control_0(alu_op, funct, op);

initial begin
    $dumpfile("tb_alu_control.vcd");
    $dumpvars(0, tb);
end

task check;
    input [3:0] want;
begin
    checks = checks + 1;
    if (op !== want) begin
        $display("FAIL: alu_op=%b funct=%b op=%b (expected %b)", alu_op, funct, op, want);
        errors = errors + 1;
    end
end
endtask

initial begin
    errors = 0; checks = 0;
    functs[0] = F_ADD; functs[1] = F_SUB; functs[2] = F_AND; functs[3] = F_OR; functs[4] = F_SLT;
    ops[0]    = ADD;   ops[1]    = SUB;   ops[2]    = AND;   ops[3]    = OR;   ops[4]    = SLT;

    // Walkthrough: one row per instruction
$monitor("time=%0t alu_op=%b funct=%b op=%b", $time, alu_op, funct, op);
    #0  alu_op = 2'b00; funct = 6'bxxxxxx;     // lw / sw / addi
    #10 check(ADD); alu_op = 2'b01;             // beq
    #10 check(SUB); alu_op = 2'b10; funct = F_ADD;
    #10 check(ADD); funct = F_SUB;
    #10 check(SUB); funct = F_AND;
    #10 check(AND); funct = F_OR;
    #10 check(OR);  funct = F_SLT;
    #10 check(SLT);
    $monitoroff;

    // lw/sw/addi and beq ignore funct, so try every funct value
    for (n = 0; n < 64; n = n + 1) begin
        funct = n;
        alu_op = 2'b00; #1 check(ADD);
        alu_op = 2'b01; #1 check(SUB);
    end

    // R-type: every supported funct
    alu_op = 2'b10;
    for (n = 0; n < 5; n = n + 1) begin
        funct = functs[n];
        #1 check(ops[n]);
    end

    if (errors == 0) $display("PASS: tb_alu_control (%0d checks)", checks);
    else             $display("FAIL: tb_alu_control (%0d of %0d checks failed)", errors, checks);
    $finish;
end
endmodule
