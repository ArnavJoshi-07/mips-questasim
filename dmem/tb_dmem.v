module tb;
reg clk, mem_write;
reg [31:0] addr, write_data;
wire [31:0] read_data;
integer errors, checks, w;

dmem dmem_0(clk, mem_write, addr, write_data, read_data);

// A different, non-zero value for every word
function [31:0] pattern;
    input integer w;
    pattern = (32'h00010001 * w) ^ 32'h5a5a5a5a;
endfunction

task check;
    input [31:0] want;
    input [8*24:1] what;
begin
    checks = checks + 1;
    if (read_data !== want) begin
        $display("FAIL: %0s: addr=%h read_data=%h, expected %h (time %0t)",
                 what, addr, read_data, want, $time);
        errors = errors + 1;
    end
end
endtask

initial begin
    $dumpfile("tb_dmem.vcd");
    $dumpvars(0, tb);
end

initial clk = 1'b0;
always #5 clk = ~clk;

// dmem writes on the rising edge (t = 5, 15, 25, ...), so inputs change at
// t = 2, 12, 22, ... to stay clear of it.
initial begin
    errors = 0; checks = 0;

    // Walkthrough: the sw / lw sequence fibonacci.asm starts with
$monitor("time=%0t mem_write=%b addr=%h write_data=%h read_data=%h",
         $time, mem_write, addr, write_data, read_data);
    #2  mem_write = 1'b0; addr = 32'h0; write_data = 32'h0;
    #10 check(32'h0, "starts at 0");
    mem_write = 1'b1; addr = 32'h0; write_data = 32'd0;     // sw $t0, 0($s0)
    #10 mem_write = 1'b1; addr = 32'h4; write_data = 32'd1; // sw $t1, 4($s0)
    #10 mem_write = 1'b1; addr = 32'h8; write_data = 32'd1; // sw $t7, 0($s0)
    #10 mem_write = 1'b0; addr = 32'h4;                     // lw $t6, -4($s0)
    #10 check(32'd1, "lw after sw");
    addr = 32'h8;
    #10 check(32'd1, "lw third term");
    $monitoroff;

    // Write every word, then read each one back
    for (w = 0; w < 256; w = w + 1) begin
        mem_write = 1'b1; addr = 4 * w; write_data = pattern(w);
        #10;
    end
    mem_write = 1'b0;
    for (w = 0; w < 256; w = w + 1) begin
        addr = 4 * w;
        #1 check(pattern(w), "read back");
    end

    // The read is combinational: read_data follows addr with no clock edge
    #1 addr = 32'h10;
    #1 check(pattern(4), "read without clock");

    // Nothing is written while mem_write is low
    #8 mem_write = 1'b0; addr = 32'h1c; write_data = 32'hdeadbeef;
    #10 check(pattern(7), "mem_write=0 keeps word");

    // A write appears only after the rising edge: the old value is seen
    // before it and the new value after it
    @(negedge clk) mem_write = 1'b1; addr = 32'h20; write_data = 32'h12345678;
    #1  check(pattern(8), "after falling edge");
    #3  check(pattern(8), "just before edge");
    #2  check(32'h12345678, "after rising edge");
    #4  mem_write = 1'b0;

    // The low two address bits are ignored on reads and writes
    #10 mem_write = 1'b1; addr = 32'h27; write_data = 32'hcafef00d;
    #10 mem_write = 1'b0; addr = 32'h24;
    #1  check(32'hcafef00d, "write with low bits");
        addr = 32'h26;
    #1  check(32'hcafef00d, "read with low bits");

    // Addresses wrap every 1 KB
        addr = 32'h400;
    #1  check(pattern(0), "wrap 0x400");

    if (errors == 0) $display("PASS: tb_dmem (%0d checks)", checks);
    else             $display("FAIL: tb_dmem (%0d of %0d checks failed)", errors, checks);
    $finish;
end
endmodule
