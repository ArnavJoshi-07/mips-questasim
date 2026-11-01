// Load-use hazard detection. A lw has its data only at the end of MEM, so
// the instruction right behind it cannot get the value by forwarding when it
// reaches EX. When the instruction in ID reads the register that a lw in EX
// is loading, stall is raised for one cycle:
//   - the PC and IF/ID hold, so the dependent instruction waits in ID;
//   - ID/EX is flushed, so a bubble (all control bits 0) goes into EX.
// One cycle later the lw is in WB and the forwarding unit hands its data
// over from MEM/WB.
//
// lw writes rt, so rt_ex is its destination. A lw to $zero is dropped and
// never stalls. The check does not look at whether the ID instruction really
// reads rt (addi and lw use it as a destination, j has address bits there),
// so a few stalls are not needed; they cost a cycle but are never wrong.

module hazard_unit(input wire mem_read_ex,
                   input wire [4:0] rt_ex, rs_id, rt_id,
                   output wire stall);

wire ex_loads;                              // EX holds a lw to a register other than $zero
wire rs_eq, rt_eq;

assign ex_loads = mem_read_ex & (|rt_ex);

// 5-bit equality: every bit pair matches (XNOR), ANDed together
assign rs_eq = &(rs_id ~^ rt_ex);
assign rt_eq = &(rt_id ~^ rt_ex);

assign stall = ex_loads & (rs_eq | rt_eq);

endmodule
