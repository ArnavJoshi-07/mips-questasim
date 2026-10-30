module tb;
reg [15:0] i;
wire [31:0] o;

// Signed copies so $monitor can print the values as decimals
wire signed [15:0] i_s = i;
wire signed [31:0] o_s = o;
integer errors, checks, n;

sign_extend sign_extend_0(i, o);

initial begin
    $dumpfile("tb_sign_extend.vcd");
    $dumpvars(0, tb);
end

task check;
begin
    checks = checks + 1;
    if (o !== {{16{i[15]}}, i}) begin
        $display("FAIL: i=%h o=%h (expected %h)", i, o, {{16{i[15]}}, i});
        errors = errors + 1;
    end
end
endtask

initial begin
    errors = 0; checks = 0;

    // Walkthrough: positive, negative and boundary immediates
$monitor("time=%0t i=%h (%0d) o=%h (%0d)", $time, i, i_s, o, o_s);
    #0  i = 16'h0004;
    #10 check; i = 16'hfffc;
    #10 check; i = 16'h7fff;
    #10 check; i = 16'h8000;
    #10 check; i = 16'h0000;
    #10 check;
    $monitoroff;

    // Every 16-bit immediate
    for (n = 0; n < 65536; n = n + 1) begin
        i = n;
        #1 check;
    end

    if (errors == 0) $display("PASS: tb_sign_extend (%0d checks)", checks);
    else             $display("FAIL: tb_sign_extend (%0d of %0d checks failed)", errors, checks);
    $finish;
end
endmodule
