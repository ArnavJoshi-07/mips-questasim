module tb;
reg clk, reset;

// All inputs and all outputs as one vector each, in port order:
//   [71:69] mem_write reg_write mem_to_reg
//   [68:5]  alu_result, write_data
//   [4:0]   write_reg
reg  [71:0] in;
wire [71:0] out;

ex_mem_reg dut(clk, reset, in[71], in[70], in[69], in[68:37], in[36:5], in[4:0],
               out[71], out[70], out[69], out[68:37], out[36:5], out[4:0]);

integer errors, checks, n;
reg [31:0] seed;

task check;
    input [71:0] want;
    input [8*24:1] what;
begin
    checks = checks + 1;
    if (out !== want) begin
        $display("FAIL: %0s: got %h, expected %h (time %0t)", what, out, want, $time);
        errors = errors + 1;
    end
end
endtask

initial begin
    $dumpfile("tb_ex_mem_reg.vcd");
    $dumpvars(0, tb);
end

initial clk = 1'b0;
always #5 clk = ~clk;

// The register loads on the rising edge (t = 5, 15, 25, ...), so inputs
// change at t = 2, 12, 22, ... and are checked 10 later, after the next edge.
initial begin
$monitor("time=%0t reset=%b ctrl=%b alu_result=%h write_data=%h write_reg=%0d",
         $time, reset, out[71:69], out[68:37], out[36:5], out[4:0]);
    errors = 0; checks = 0; seed = 32'd2026;

    // Reset clears every field
    #2 reset = 1'b1; in = {$random(seed), $random(seed), $random(seed)};
    #10 check(72'h0, "reset");
    reset = 1'b0;

    // sw $t7, 0($s0) with $s0 = 8, $t7 = 1: store 1 at address 8
    in = {3'b100, 32'd8, 32'd1, 5'd15};
    #10 check(in, "sw");

    // lw $t6, -4($s0) with $s0 = 12: load from address 8 into $t6
    in = {3'b011, 32'd8, 32'd0, 5'd14};
    #10 check(in, "lw");

    // add $t7, $t5, $t6 = 2
    in = {3'b010, 32'd2, 32'd0, 5'd15};
    #10 check(in, "add");
    $monitoroff;

    // Random values for every field pass through unchanged
    for (n = 0; n < 50; n = n + 1) begin
        in = {$random(seed), $random(seed), $random(seed)};
        #10 check(in, "random");
    end

    // Reset clears it again
    reset = 1'b1;
    #10 check(72'h0, "reset again");

    if (errors == 0) $display("PASS: tb_ex_mem_reg (%0d checks)", checks);
    else             $display("FAIL: tb_ex_mem_reg (%0d of %0d checks failed)", errors, checks);
    $finish;
end
endmodule
