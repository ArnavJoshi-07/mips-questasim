module tb;
reg [4:0] rs_ex, rt_ex, write_reg_mem, write_reg_wb;
reg reg_write_mem, reg_write_wb;
wire [1:0] forward_a, forward_b;

localparam REG = 2'b00, WB = 2'b01, MEM = 2'b10;

integer errors, checks, rs, mem, wb, rw;

forwarding_unit dut(rs_ex, rt_ex, write_reg_mem, write_reg_wb,
                    reg_write_mem, reg_write_wb, forward_a, forward_b);

initial begin
    $dumpfile("tb_forwarding_unit.vcd");
    $dumpvars(0, tb);
end

// Reference model: where one operand that reads register src comes from
function [1:0] source;
    input [4:0] src;
begin
    if (reg_write_mem && write_reg_mem != 0 && write_reg_mem == src)
        source = MEM;
    else if (reg_write_wb && write_reg_wb != 0 && write_reg_wb == src)
        source = WB;
    else
        source = REG;
end
endfunction

task check;
    input [1:0] want_a, want_b;
begin
    checks = checks + 1;
    if (forward_a !== want_a || forward_b !== want_b) begin
        $display("FAIL: rs=%0d rt=%0d mem=%0d(%b) wb=%0d(%b): forward_a=%b forward_b=%b (expected %b %b)",
                 rs_ex, rt_ex, write_reg_mem, reg_write_mem, write_reg_wb, reg_write_wb,
                 forward_a, forward_b, want_a, want_b);
        errors = errors + 1;
    end
end
endtask

// Set every input for one case
task set;
    input [4:0] rs, rt, mem, wb;
    input rw_mem, rw_wb;
begin
    rs_ex = rs; rt_ex = rt; write_reg_mem = mem; write_reg_wb = wb;
    reg_write_mem = rw_mem; reg_write_wb = rw_wb;
end
endtask

initial begin
    errors = 0; checks = 0;

    // Walkthrough: one row per situation, using $t0 = 8, $t1 = 9, $t2 = 10
$monitor("time=%0t rs=%0d rt=%0d mem=%0d rw_mem=%b wb=%0d rw_wb=%b forward_a=%b forward_b=%b",
         $time, rs_ex, rt_ex, write_reg_mem, reg_write_mem, write_reg_wb, reg_write_wb,
         forward_a, forward_b);
    set(9, 10, 11, 12, 1, 1);                   // no dependence
    #10 check(REG, REG); set(8, 10, 8, 12, 1, 1);   // rs from EX/MEM
    #10 check(MEM, REG); set(9, 8, 8, 12, 1, 1);    // rt from EX/MEM (e.g. sw data)
    #10 check(REG, MEM); set(8, 10, 11, 8, 1, 1);   // rs from MEM/WB
    #10 check(WB,  REG); set(9, 8, 11, 8, 1, 1);    // rt from MEM/WB
    #10 check(REG, WB);  set(8, 8, 8, 12, 1, 1);    // rs and rt both from EX/MEM
    #10 check(MEM, MEM); set(8, 9, 8, 9, 1, 1);     // rs from EX/MEM, rt from MEM/WB
    #10 check(MEM, WB);  set(8, 9, 8, 8, 1, 1);     // double hazard: EX/MEM is newer
    #10 check(MEM, REG); set(8, 9, 8, 8, 0, 1);     // EX/MEM is a sw/beq: MEM/WB used
    #10 check(WB,  REG); set(8, 9, 8, 8, 0, 0);     // neither stage writes
    #10 check(REG, REG); set(0, 0, 0, 0, 1, 1);     // nops in every stage: $zero never forwards
    #10 check(REG, REG); set(0, 8, 0, 8, 1, 1);     // $zero in EX/MEM, $t0 in MEM/WB
    #10 check(REG, WB);
    $monitoroff;

    // Every combination of one source register, write_reg_mem, write_reg_wb
    // and the two reg_write bits, first as rs and then as rt. The other
    // operand runs through the registers in a different order, so that rs
    // and rt land in different cases in the same step.
    for (rw = 0; rw < 4; rw = rw + 1)
        for (rs = 0; rs < 32; rs = rs + 1)
            for (mem = 0; mem < 32; mem = mem + 1)
                for (wb = 0; wb < 32; wb = wb + 1) begin
                    set(rs, (rs * 7 + mem + wb) % 32, mem, wb, rw[1], rw[0]);
                    #1 check(source(rs_ex), source(rt_ex));
                    set((rs * 7 + mem + wb) % 32, rs, mem, wb, rw[1], rw[0]);
                    #1 check(source(rs_ex), source(rt_ex));
                end

    if (errors == 0) $display("PASS: tb_forwarding_unit (%0d checks)", checks);
    else             $display("FAIL: tb_forwarding_unit (%0d of %0d checks failed)", errors, checks);
    $finish;
end
endmodule
