// Forwarding unit. Decides where each ALU operand in EX comes from when an
// older instruction still in the pipeline writes the register it reads:
//
//   forward_a / forward_b   source of the rs / rt operand
//     00                    register file (value read in ID)
//     10                    EX/MEM: alu_result_mem, from the instruction
//                           one ahead
//     01                    MEM/WB: write_data_wb, from the instruction two
//                           ahead (the mem_to_reg mux output, so lw works)
//
// An instruction three or more ahead has already written the register file,
// which is written on the falling edge before ID reads it, so it needs no
// forwarding.
//
// A stage only forwards when it writes a register (reg_write) and that
// register is not $zero: writes to $zero are dropped, and nops (all zeros)
// are R-type instructions that "write" $zero. When both stages match, EX/MEM
// wins because it holds the newer value.
//
// The codes follow Patterson and Hennessy and match the select inputs of
// mux4_32: i0 = register file, i1 = MEM/WB, i2 = EX/MEM.

module forwarding_unit(input wire [4:0] rs_ex, rt_ex,
                       input wire [4:0] write_reg_mem, write_reg_wb,
                       input wire reg_write_mem, reg_write_wb,
                       output wire [1:0] forward_a, forward_b);

wire mem_writes, wb_writes;                 // stage writes a register other than $zero
wire rs_eq_mem, rt_eq_mem, rs_eq_wb, rt_eq_wb;

assign mem_writes = reg_write_mem & (|write_reg_mem);
assign wb_writes  = reg_write_wb  & (|write_reg_wb);

// 5-bit equality: every bit pair matches (XNOR), ANDed together
assign rs_eq_mem = &(rs_ex ~^ write_reg_mem);
assign rt_eq_mem = &(rt_ex ~^ write_reg_mem);
assign rs_eq_wb  = &(rs_ex ~^ write_reg_wb);
assign rt_eq_wb  = &(rt_ex ~^ write_reg_wb);

assign forward_a[1] = mem_writes & rs_eq_mem;
assign forward_a[0] = wb_writes  & rs_eq_wb & ~forward_a[1];
assign forward_b[1] = mem_writes & rt_eq_mem;
assign forward_b[0] = wb_writes  & rt_eq_wb & ~forward_b[1];

endmodule
