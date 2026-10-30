module tb;
reg [3:0] op;
reg [31:0] i0, i1;
wire [31:0] o;
wire zero, overflow;

localparam AND = 4'b0000, OR = 4'b0001, ADD = 4'b0010,
           SUB = 4'b0110, SLT = 4'b0111, NOR = 4'b1100;

reg [3:0] ops [0:5];
reg [31:0] vals [0:11];
reg [31:0] exp_o;
reg exp_v;
integer errors, checks, a, b, k, n;

alu alu_0(op, i0, i1, o, zero, overflow);

initial begin
    $dumpfile("tb_alu.vcd");
    $dumpvars(0, tb);
end

// Compares the outputs against a behavioural model of the same operation.
// Overflow is only meaningful for add and sub, so it is only checked there.
task check;
begin
    case (op)
        AND:     exp_o = i0 & i1;
        OR:      exp_o = i0 | i1;
        ADD:     exp_o = i0 + i1;
        SUB:     exp_o = i0 - i1;
        SLT:     exp_o = ($signed(i0) < $signed(i1)) ? 32'd1 : 32'd0;
        NOR:     exp_o = ~(i0 | i1);
        default: exp_o = 32'hxxxxxxxx;
    endcase
    exp_v = (op == ADD) ? (i0[31] == i1[31]) && (exp_o[31] != i0[31]) :
            (op == SUB) ? (i0[31] != i1[31]) && (exp_o[31] != i0[31]) : 1'b0;

    checks = checks + 1;
    if (o !== exp_o || zero !== (exp_o == 32'd0) ||
        ((op == ADD || op == SUB) && overflow !== exp_v)) begin
        $display("FAIL: op=%b i0=%h i1=%h o=%h (expected %h) zero=%b overflow=%b (expected %b)",
                 op, i0, i1, o, exp_o, zero, overflow, exp_v);
        errors = errors + 1;
    end
end
endtask

initial begin
    errors = 0; checks = 0;
    ops[0] = AND; ops[1] = OR; ops[2] = ADD; ops[3] = SUB; ops[4] = SLT; ops[5] = NOR;
    vals[0] = 32'h00000000;  vals[1]  = 32'h00000001;  vals[2]  = 32'h00000002;
    vals[3] = 32'h7fffffff;  vals[4]  = 32'h80000000;  vals[5]  = 32'h80000001;
    vals[6] = 32'hffffffff;  vals[7]  = 32'hfffffffe;  vals[8]  = 32'haa55aa55;
    vals[9] = 32'h55aa55aa;  vals[10] = 32'h0000ffff;  vals[11] = 32'h12345678;

    // Walkthrough of each operation, one #10 step each
$monitor("time=%0t op=%b i0=%h i1=%h o=%h zero=%b overflow=%b", $time, op, i0, i1, o, zero, overflow);
    #0  op = AND; i0 = 32'haa55aa55; i1 = 32'h55aa55aa;
    #10 check; op = OR;
    #10 check; op = ADD; i0 = 32'd25;         i1 = 32'd17;
    #10 check; op = SUB;
    #10 check; op = SUB; i0 = 32'd17;         i1 = 32'd17;
    #10 check; op = SLT; i0 = 32'hfffffff6;   i1 = 32'd5;
    #10 check; op = SLT; i0 = 32'd5;          i1 = 32'hfffffff6;
    #10 check; op = ADD; i0 = 32'h7fffffff;   i1 = 32'd1;
    #10 check; op = NOR; i0 = 32'h0f0f0f0f;   i1 = 32'h00ff00ff;
    #10 check;
    $monitoroff;

    // Every operation on every pair of edge values
    for (k = 0; k < 6; k = k + 1)
        for (a = 0; a < 12; a = a + 1)
            for (b = 0; b < 12; b = b + 1) begin
                op = ops[k]; i0 = vals[a]; i1 = vals[b];
                #1 check;
            end

    // Random operands
    for (n = 0; n < 2000; n = n + 1) begin
        op = ops[{$random} % 6]; i0 = $random; i1 = $random;
        #1 check;
    end

    if (errors == 0) $display("PASS: tb_alu (%0d checks)", checks);
    else             $display("FAIL: tb_alu (%0d of %0d checks failed)", errors, checks);
    $finish;
end
endmodule
