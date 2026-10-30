module tb;
reg clk, reset, load, in;
reg [0:7] i;
reg [0:2] j;
wire o, out;
integer errors;

mux8 mux8_0(i, j[0], j[1], j[2], o);
dfrl dfrl_0(clk, reset, load, in, out);

initial begin
    $dumpfile("tb_smoke.vcd");
    $dumpvars(0, tb);
end

initial begin
    reset = 1'b1;
    #12.5 reset = 1'b0;
end

initial clk = 1'b0;
always #5 clk = ~clk;

initial begin
$monitor("time=%0t reset=%b i=%b j=%o o=%b load=%b in=%b out=%b", $time, reset, i, j, o, load, in, out);
    errors = 0;
    #0  i = 8'b0010_0000; j = 3'o2; load = 1'b0; in = 1'b0;
    #10 if (o !== 1'b1)   begin $display("FAIL: mux8 j=2 gave %b", o);   errors = errors + 1; end
        j = 3'o3;
    #10 if (o !== 1'b0)   begin $display("FAIL: mux8 j=3 gave %b", o);   errors = errors + 1; end
        load = 1'b1; in = 1'b1;
    #10 if (out !== 1'b1) begin $display("FAIL: dfrl load 1 gave %b", out); errors = errors + 1; end
        load = 1'b0; in = 1'b0;
    #10 if (out !== 1'b1) begin $display("FAIL: dfrl hold gave %b", out);   errors = errors + 1; end
        load = 1'b1; in = 1'b0;
    #10 if (out !== 1'b0) begin $display("FAIL: dfrl load 0 gave %b", out); errors = errors + 1; end

    if (errors == 0) $display("PASS: tb_smoke");
    else             $display("FAIL: tb_smoke (%0d errors)", errors);
    $finish;
end
endmodule
