module tb;
reg mem_read_ex;
reg [4:0] rt_ex, rs_id, rt_id;
wire stall;

integer errors, checks, mr, lt, rs, rt;

hazard_unit dut(mem_read_ex, rt_ex, rs_id, rt_id, stall);

initial begin
    $dumpfile("tb_hazard_unit.vcd");
    $dumpvars(0, tb);
end

// Reference model
function want_stall;
    input dummy;
    want_stall = mem_read_ex && rt_ex != 0 && (rs_id == rt_ex || rt_id == rt_ex);
endfunction

task check;
    input want;
begin
    checks = checks + 1;
    if (stall !== want) begin
        $display("FAIL: mem_read_ex=%b rt_ex=%0d rs_id=%0d rt_id=%0d: stall=%b (expected %b)",
                 mem_read_ex, rt_ex, rs_id, rt_id, stall, want);
        errors = errors + 1;
    end
end
endtask

task set;
    input mr_in;
    input [4:0] lt_in, rs_in, rt_in;
begin
    mem_read_ex = mr_in; rt_ex = lt_in; rs_id = rs_in; rt_id = rt_in;
end
endtask

initial begin
    errors = 0; checks = 0;

    // Walkthrough, using $t0 = 8, $t1 = 9, $t2 = 10
$monitor("time=%0t mem_read_ex=%b rt_ex=%0d rs_id=%0d rt_id=%0d stall=%b",
         $time, mem_read_ex, rt_ex, rs_id, rt_id, stall);
    set(1, 8, 8, 10);       // lw $t0 ; add $t1, $t0, $t2   rs matches
    #10 check(1); set(1, 8, 10, 8);     // lw $t0 ; add $t1, $t2, $t0   rt matches
    #10 check(1); set(1, 8, 8, 8);      // lw $t0 ; add $t1, $t0, $t0   both match
    #10 check(1); set(1, 8, 9, 10);     // lw $t0 ; add $t1, $t1, $t2   independent
    #10 check(0); set(0, 8, 8, 10);     // add $t0 in EX: forwarding covers it
    #10 check(0); set(1, 0, 0, 0);      // lw $zero ; nop: never stalls
    #10 check(0); set(0, 0, 0, 0);      // nops everywhere
    #10 check(0);
    $monitoroff;

    // Every combination
    for (mr = 0; mr < 2; mr = mr + 1)
        for (lt = 0; lt < 32; lt = lt + 1)
            for (rs = 0; rs < 32; rs = rs + 1)
                for (rt = 0; rt < 32; rt = rt + 1) begin
                    set(mr[0], lt, rs, rt);
                    #1 check(want_stall(0));
                end

    if (errors == 0) $display("PASS: tb_hazard_unit (%0d checks)", checks);
    else             $display("FAIL: tb_hazard_unit (%0d of %0d checks failed)", errors, checks);
    $finish;
end
endmodule
