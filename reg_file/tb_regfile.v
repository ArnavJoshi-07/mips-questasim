module tb;
reg clk, reset, wr;
reg [4:0] rd_addr_a, rd_addr_b, wr_addr;
reg [31:0] d_in;
wire [31:0] d_out_a, d_out_b;
integer errors, checks, r;

reg_file reg_file_0(
    clk, reset, wr,
    rd_addr_a, rd_addr_b, wr_addr,
    d_in, d_out_a, d_out_b
);

// A different, non-zero value for every register
function [31:0] pattern;
    input integer r;
    pattern = (32'h01010101 * r) ^ 32'ha5a5a5a5;
endfunction

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
    $dumpfile("tb_regfile.vcd");
    $dumpvars(0, tb);
end

initial begin
    reset = 1'b1;
    #12.5 reset = 1'b0;
end

initial clk = 1'b0;
always #5 clk = ~clk;

// The register file writes on the falling edge (t = 10, 20, 30, ...), so
// inputs change at t = 2, 12, 22, ... to stay clear of it.
initial begin
$monitor("time=%0t reset=%b wr=%b wr_addr=%0d d_in=%h rd_addr_a=%0d d_out_a=%h rd_addr_b=%0d d_out_b=%h",
         $time, reset, wr, wr_addr, d_in, rd_addr_a, d_out_a, rd_addr_b, d_out_b);
    errors = 0; checks = 0;

    // Reset clears every register
    #2  wr = 1'b0; wr_addr = 5'd0; d_in = 32'h0; rd_addr_a = 5'd1; rd_addr_b = 5'd31;
    #10 check(d_out_a, 32'h0, "reset clears r1");
        check(d_out_b, 32'h0, "reset clears r31");

    // Write every register, then read each one back on both ports
    for (r = 1; r < 32; r = r + 1) begin
        wr = 1'b1; wr_addr = r; d_in = pattern(r);
        #10;
    end
    wr = 1'b0;
    for (r = 0; r < 32; r = r + 1) begin
        rd_addr_a = r; rd_addr_b = 31 - r;
        #10 check(d_out_a, (r == 0) ? 32'h0 : pattern(r), "read port a");
            check(d_out_b, (r == 31) ? 32'h0 : pattern(31 - r), "read port b");
    end

    // $zero ignores writes
    wr = 1'b1; wr_addr = 5'd0; d_in = 32'hffffffff; rd_addr_a = 5'd0;
    #10 check(d_out_a, 32'h0, "$zero stays 0");

    // Nothing is written while wr is low
    wr = 1'b0; wr_addr = 5'd7; d_in = 32'hdeadbeef; rd_addr_a = 5'd7;
    #10 check(d_out_a, pattern(7), "wr=0 leaves r7");

    // Write and read the same register in one cycle: the old value is seen
    // until the falling edge (even after the rising edge) and the new value after it
    wr = 1'b1; wr_addr = 5'd9; d_in = 32'h12345678; rd_addr_a = 5'd9; rd_addr_b = 5'd9;
    #1  check(d_out_a, pattern(9), "r9 before rising edge");
    #4  check(d_out_a, pattern(9), "r9 after rising edge");
    #4  check(d_out_a, 32'h12345678, "r9 after falling edge");
        check(d_out_b, 32'h12345678, "r9 on port b");
    #1  wr = 1'b0;

    // Reset again clears the registers
    reset = 1'b1;
    #10 check(d_out_a, 32'h0, "second reset clears r9");
    reset = 1'b0;

    if (errors == 0) $display("PASS: tb_regfile (%0d checks)", checks);
    else             $display("FAIL: tb_regfile (%0d of %0d checks failed)", errors, checks);
    $finish;
end
endmodule
