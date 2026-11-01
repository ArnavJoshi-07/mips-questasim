module tb;
reg clk, reset;

// All inputs and all outputs as one vector each, in port order:
//   [70:69] reg_write mem_to_reg
//   [68:5]  mem_data, alu_result
//   [4:0]   write_reg
reg  [70:0] in;
wire [70:0] out;

mem_wb_reg dut(clk, reset, in[70], in[69], in[68:37], in[36:5], in[4:0],
               out[70], out[69], out[68:37], out[36:5], out[4:0]);

integer errors, checks, n;
reg [31:0] seed;

task check;
    input [70:0] want;
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
    $dumpfile("tb_mem_wb_reg.vcd");
    $dumpvars(0, tb);
end

initial clk = 1'b0;
always #5 clk = ~clk;

// The register loads on the rising edge (t = 5, 15, 25, ...), so inputs
// change at t = 2, 12, 22, ... and are checked 10 later, after the next edge.
initial begin
$monitor("time=%0t reset=%b ctrl=%b mem_data=%h alu_result=%h write_reg=%0d",
         $time, reset, out[70:69], out[68:37], out[36:5], out[4:0]);
    errors = 0; checks = 0; seed = 32'd2026;

    // Reset clears every field
    #2 reset = 1'b1; in = {$random(seed), $random(seed), $random(seed)};
    #10 check(71'h0, "reset");
    reset = 1'b0;

    // lw $t6, -4($s0): word 1 loaded from address 8, written to $t6
    in = {2'b11, 32'd1, 32'd8, 5'd14};
    #10 check(in, "lw");

    // add $t7, $t5, $t6 = 2: the ALU result is written to $t7
    in = {2'b10, 32'd0, 32'd2, 5'd15};
    #10 check(in, "add");

    // sw: nothing to write back
    in = {2'b00, 32'd0, 32'd8, 5'd15};
    #10 check(in, "sw");
    $monitoroff;

    // Random values for every field pass through unchanged
    for (n = 0; n < 50; n = n + 1) begin
        in = {$random(seed), $random(seed), $random(seed)};
        #10 check(in, "random");
    end

    // Reset clears it again
    reset = 1'b1;
    #10 check(71'h0, "reset again");

    if (errors == 0) $display("PASS: tb_mem_wb_reg (%0d checks)", checks);
    else             $display("FAIL: tb_mem_wb_reg (%0d of %0d checks failed)", errors, checks);
    $finish;
end
endmodule
