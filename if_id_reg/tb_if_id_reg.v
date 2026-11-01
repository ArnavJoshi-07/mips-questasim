module tb;
reg clk, reset, load, flush;
reg [31:0] pc_plus4_if, instr_if;
wire [31:0] pc_plus4_id, instr_id;
integer errors, checks, n;
reg [31:0] seed;

if_id_reg dut(clk, reset, load, flush, pc_plus4_if, instr_if, pc_plus4_id, instr_id);

task check;
    input [31:0] want_pc_plus4, want_instr;
    input [8*24:1] what;
begin
    checks = checks + 1;
    if (pc_plus4_id !== want_pc_plus4 || instr_id !== want_instr) begin
        $display("FAIL: %0s: pc_plus4=%h instr=%h, expected %h %h (time %0t)",
                 what, pc_plus4_id, instr_id, want_pc_plus4, want_instr, $time);
        errors = errors + 1;
    end
end
endtask

initial begin
    $dumpfile("tb_if_id_reg.vcd");
    $dumpvars(0, tb);
end

initial clk = 1'b0;
always #5 clk = ~clk;

// The register loads on the rising edge (t = 5, 15, 25, ...), so inputs
// change at t = 2, 12, 22, ... and are checked 10 later, after the next edge.
initial begin
$monitor("time=%0t reset=%b load=%b flush=%b in=%h,%h out=%h,%h",
         $time, reset, load, flush, pc_plus4_if, instr_if, pc_plus4_id, instr_id);
    errors = 0; checks = 0; seed = 32'd2026;

    // Reset clears both fields
    #2  reset = 1'b1; load = 1'b1; flush = 1'b0;
        pc_plus4_if = 32'h4; instr_if = 32'h20100000;
    #10 check(32'h0, 32'h0, "reset");
    reset = 1'b0;

    // Normal fetch: the instruction moves into ID one edge later
    #10 check(32'h4, 32'h20100000, "load addi");
    pc_plus4_if = 32'h8; instr_if = 32'h20080000;
    #10 check(32'h8, 32'h20080000, "load next");

    // load = 0 holds the instruction in ID while IF moves on (load-use stall)
    load = 1'b0; pc_plus4_if = 32'hc; instr_if = 32'h01ae7820;
    #10 check(32'h8, 32'h20080000, "stall cycle 1");
    #10 check(32'h8, 32'h20080000, "stall cycle 2");
    load = 1'b1;
    #10 check(32'hc, 32'h01ae7820, "after stall");

    // flush = 1 turns the fetched instruction into a nop (taken branch)
    flush = 1'b1; pc_plus4_if = 32'h10; instr_if = 32'hae080000;
    #10 check(32'h0, 32'h0, "flush");
    flush = 1'b0;
    #10 check(32'h10, 32'hae080000, "after flush");

    // flush wins over load = 0
    load = 1'b0; flush = 1'b1;
    #10 check(32'h0, 32'h0, "flush while stalled");
    load = 1'b1; flush = 1'b0;
    $monitoroff;

    // Random words pass through unchanged
    for (n = 0; n < 50; n = n + 1) begin
        pc_plus4_if = $random(seed); instr_if = $random(seed);
        #10 check(pc_plus4_if, instr_if, "random");
    end

    if (errors == 0) $display("PASS: tb_if_id_reg (%0d checks)", checks);
    else             $display("FAIL: tb_if_id_reg (%0d of %0d checks failed)", errors, checks);
    $finish;
end
endmodule
