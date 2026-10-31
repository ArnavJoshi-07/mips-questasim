// Tests the word-wide building blocks in library.v: fa, adder32, mux2_5,
// mux2_32, mux4_32 and dfrl_32. The 1-bit mux, demux and flip-flop modules
// are covered through these and through the register file testbench.
module tb;
reg fa_i0, fa_i1, fa_cin;
wire fa_sum, fa_cout;

reg [31:0] a, b, c, d;
reg [4:0] a5, b5;
reg j, j1, j0;
wire [31:0] sum, o2, o4;
wire [4:0] o5;

reg clk, reset, load;
reg [31:0] in;
wire [31:0] out;

integer errors, checks, n;
reg [31:0] seed;

fa fa_0(fa_i0, fa_i1, fa_cin, fa_sum, fa_cout);
adder32 adder32_0(a, b, sum);
mux2_5 mux2_5_0(a5, b5, j, o5);
mux2_32 mux2_32_0(a, b, j, o2);
mux4_32 mux4_32_0(a, b, c, d, j1, j0, o4);
dfrl_32 dfrl_32_0(clk, reset, load, in, out);

task check;
    input [31:0] got, want;
    input [8*24:1] what;
begin
    checks = checks + 1;
    if (got !== want) begin
        $display("FAIL: %0s: got %h, expected %h (time %0t)", what, got, want, $time);
        errors = errors + 1;
    end
end
endtask

initial begin
    $dumpfile("tb_library.vcd");
    $dumpvars(0, tb);
end

initial clk = 1'b0;
always #5 clk = ~clk;

initial begin
    errors = 0; checks = 0; seed = 32'd2026;
    j = 1'b0; j1 = 1'b0; j0 = 1'b0;
    a5 = 5'd0; b5 = 5'd0; c = 32'h0; d = 32'h0;

    // fa: every input combination
    for (n = 0; n < 8; n = n + 1) begin
        {fa_i0, fa_i1, fa_cin} = n;
        #1 check({fa_cout, fa_sum}, fa_i0 + fa_i1 + fa_cin, "fa");
    end

    // Walkthrough: the PC and branch-target sums the datapath needs
$monitor("time=%0t a=%h b=%h sum=%h", $time, a, b, sum);
    #10 a = 32'h00000000; b = 32'd4;          // PC + 4
    #10 check(sum, 32'h00000004, "pc + 4");
        a = 32'h0000003c; b = 32'd4;
    #10 check(sum, 32'h00000040, "pc + 4");
        a = 32'h00000024; b = 32'h0000001c;   // beq forward: 0x24 + (7 << 2)
    #10 check(sum, 32'h00000040, "branch forward");
        a = 32'h00000040; b = 32'hffffffe0;   // beq backward: 0x40 + (-8 << 2)
    #10 check(sum, 32'h00000020, "branch backward");
        a = 32'hfffffffc; b = 32'd4;          // carry out is dropped
    #10 check(sum, 32'h00000000, "wrap");
        a = 32'h7fffffff; b = 32'd1;          // carry ripples through every bit
    #10 check(sum, 32'h80000000, "full ripple");
    $monitoroff;

    // adder32: random operands
    for (n = 0; n < 2000; n = n + 1) begin
        a = $random(seed); b = $random(seed);
        #1 check(sum, a + b, "adder32");
    end

    // mux2_5 and mux2_32: random words, both selects
    for (n = 0; n < 500; n = n + 1) begin
        a = $random(seed); b = $random(seed);
        a5 = a[4:0]; b5 = b[4:0]; j = n[0];
        #1 check(o2, j ? b : a, "mux2_32");
           check({27'b0, o5}, j ? b5 : a5, "mux2_5");
    end

    // mux4_32: random words, all four selects
    for (n = 0; n < 1000; n = n + 1) begin
        a = $random(seed); b = $random(seed); c = $random(seed); d = $random(seed);
        {j1, j0} = n[1:0];
        #1 case ({j1, j0})
            2'b00: check(o4, a, "mux4_32 sel 00");
            2'b01: check(o4, b, "mux4_32 sel 01");
            2'b10: check(o4, c, "mux4_32 sel 10");
            2'b11: check(o4, d, "mux4_32 sel 11");
        endcase
    end

    // dfrl_32: inputs change just after the falling edge, checks follow the
    // next rising edge
    @(negedge clk) reset = 1'b1; load = 1'b1; in = 32'hffffffff;
    @(negedge clk) check(out, 32'h0, "dfrl_32 reset");
    reset = 1'b0; in = 32'hdeadbeef;
    @(posedge clk) #1 check(out, 32'hdeadbeef, "dfrl_32 load");
    @(negedge clk) load = 1'b0; in = 32'h12345678;
    @(posedge clk) #1 check(out, 32'hdeadbeef, "dfrl_32 hold");
    @(negedge clk) load = 1'b1;
    #1 check(out, 32'hdeadbeef, "dfrl_32 waits for edge");
    @(posedge clk) #1 check(out, 32'h12345678, "dfrl_32 load again");
    @(negedge clk) load = 1'b0; reset = 1'b1;
    @(posedge clk) #1 check(out, 32'h0, "dfrl_32 reset over hold");

    if (errors == 0) $display("PASS: tb_library (%0d checks)", checks);
    else             $display("FAIL: tb_library (%0d of %0d checks failed)", errors, checks);
    $finish;
end
endmodule
