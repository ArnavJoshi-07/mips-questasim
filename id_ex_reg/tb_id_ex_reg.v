module tb;
reg clk, reset, load, flush;

// All inputs and all outputs as one vector each, in port order:
//   [151:143] control  reg_dst alu_src alu_op[1:0] mem_read mem_write branch
//                      reg_write mem_to_reg
//   [142:15]  pc_plus4, read_data_a, read_data_b, imm_ext
//   [14:0]    rs, rt, rd
reg  [151:0] in;
wire [151:0] out;

id_ex_reg dut(clk, reset, load, flush,
              in[151], in[150], in[149:148], in[147], in[146], in[145], in[144], in[143],
              in[142:111], in[110:79], in[78:47], in[46:15],
              in[14:10], in[9:5], in[4:0],
              out[151], out[150], out[149:148], out[147], out[146], out[145], out[144], out[143],
              out[142:111], out[110:79], out[78:47], out[46:15],
              out[14:10], out[9:5], out[4:0]);

integer errors, checks, n;
reg [31:0] seed;
reg [151:0] held;

task check;
    input [151:0] want;
    input [8*24:1] what;
begin
    checks = checks + 1;
    if (out !== want) begin
        $display("FAIL: %0s: got %h, expected %h (time %0t)", what, out, want, $time);
        errors = errors + 1;
    end
end
endtask

// A random value for every field
task randomise;
begin
    in = {$random(seed), $random(seed), $random(seed), $random(seed), $random(seed)};
end
endtask

initial begin
    $dumpfile("tb_id_ex_reg.vcd");
    $dumpvars(0, tb);
end

initial clk = 1'b0;
always #5 clk = ~clk;

// The register loads on the rising edge (t = 5, 15, 25, ...), so inputs
// change at t = 2, 12, 22, ... and are checked 10 later, after the next edge.
initial begin
$monitor("time=%0t reset=%b load=%b flush=%b ctrl_in=%b ctrl_out=%b",
         $time, reset, load, flush, in[151:143], out[151:143]);
    errors = 0; checks = 0; seed = 32'd2026;

    // Reset clears every field
    #2 reset = 1'b1; load = 1'b1; flush = 1'b0; randomise;
    #10 check(152'h0, "reset");
    reset = 1'b0;

    // Each control bit on its own reaches the right output
    for (n = 0; n < 9; n = n + 1) begin
        in = 152'h0; in[143 + n] = 1'b1;
        #10 check(in, "single control bit");
    end

    // load = 0 holds everything (stall)
    randomise;
    #10 check(in, "load");
    held = in; load = 1'b0; randomise;
    #10 check(held, "stall cycle 1");
    #10 check(held, "stall cycle 2");
    load = 1'b1;
    #10 check(in, "after stall");

    // flush = 1 clears every field, so the control signals become a bubble
    flush = 1'b1; randomise;
    #10 check(152'h0, "flush");
    flush = 1'b0;
    #10 check(in, "after flush");

    // flush wins over load = 0
    load = 1'b0; flush = 1'b1;
    #10 check(152'h0, "flush while stalled");
    load = 1'b1; flush = 1'b0;
    $monitoroff;

    // Random values for every field pass through unchanged
    for (n = 0; n < 50; n = n + 1) begin
        randomise;
        #10 check(in, "random");
    end

    if (errors == 0) $display("PASS: tb_id_ex_reg (%0d checks)", checks);
    else             $display("FAIL: tb_id_ex_reg (%0d of %0d checks failed)", errors, checks);
    $finish;
end
endmodule
