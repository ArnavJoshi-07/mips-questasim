module tb;
reg clk, reset, load, jump;
reg [31:0] target;
wire [31:0] pc, pc_next;
integer errors, checks, n;

// The PC feeds back through PC + 4, or takes target when jump is 1
assign pc_next = jump ? target : pc + 32'd4;

pc_reg pc_reg_0(clk, reset, load, pc_next, pc);

task check;
    input [31:0] want;
    input [8*24:1] what;
begin
    checks = checks + 1;
    if (pc !== want) begin
        $display("FAIL: %0s: pc=%h, expected %h (time %0t)", what, pc, want, $time);
        errors = errors + 1;
    end
end
endtask

initial begin
    $dumpfile("tb_pc_reg.vcd");
    $dumpvars(0, tb);
end

initial clk = 1'b0;
always #5 clk = ~clk;

// The PC updates on the rising edge (t = 5, 15, 25, ...), so inputs change
// at t = 2, 12, 22, ... and are checked 10 later, after the next edge.
initial begin
$monitor("time=%0t reset=%b load=%b jump=%b target=%h pc_next=%h pc=%h",
         $time, reset, load, jump, target, pc_next, pc);
    errors = 0; checks = 0;

    // Reset puts the PC at 0
    #2  reset = 1'b1; load = 1'b1; jump = 1'b0; target = 32'h0;
    #10 check(32'h0, "reset");
    reset = 1'b0;

    // Sequential fetch: 4, 8, 12, ...
    for (n = 1; n <= 5; n = n + 1)
        #10 check(4 * n, "pc + 4");

    // load = 0 freezes the PC (load-use stall), then it carries on
    load = 1'b0;
    #10 check(32'h14, "stall cycle 1");
    #10 check(32'h14, "stall cycle 2");
    load = 1'b1;
    #10 check(32'h18, "after stall");

    // Taking a branch or jump loads the target
    jump = 1'b1; target = 32'h40;
    #10 check(32'h40, "jump to target");
    jump = 1'b0;
    #10 check(32'h44, "pc + 4 after jump");

    // A jump back to the same address holds the PC there (j halt)
    jump = 1'b1; target = 32'h44;
    #10 check(32'h44, "j halt");
    #10 check(32'h44, "j halt again");
    jump = 1'b0;

    // Reset wins even while the PC is frozen
    load = 1'b0; reset = 1'b1;
    #10 check(32'h0, "reset while stalled");
    $monitoroff;

    // The PC wraps from the top of the address space to 0
    reset = 1'b0; load = 1'b1; jump = 1'b1; target = 32'hfffffffc;
    #10 check(32'hfffffffc, "top address");
    jump = 1'b0;
    #10 check(32'h0, "wraps to 0");

    if (errors == 0) $display("PASS: tb_pc_reg (%0d checks)", checks);
    else             $display("FAIL: tb_pc_reg (%0d of %0d checks failed)", errors, checks);
    $finish;
end
endmodule
