// EX/MEM pipeline register: carries the ALU result (the address for lw/sw),
// the store data (rt), the destination register and the control signals
// still needed in MEM and WB.
//
// Branches are resolved in EX, so no branch information goes further. Nothing
// ever stalls or flushes this register: once an instruction has left EX it
// always completes. It only has a reset.

module ex_mem_reg(
    input wire clk, reset,
    input wire mem_write_ex, reg_write_ex, mem_to_reg_ex,
    input wire [31:0] alu_result_ex, write_data_ex,
    input wire [4:0] write_reg_ex,
    output wire mem_write_mem, reg_write_mem, mem_to_reg_mem,
    output wire [31:0] alu_result_mem, write_data_mem,
    output wire [4:0] write_reg_mem
);

dfrl dfrl_mem_write(clk, reset, 1'b1, mem_write_ex, mem_write_mem);
dfrl dfrl_reg_write(clk, reset, 1'b1, reg_write_ex, reg_write_mem);
dfrl dfrl_mem_to_reg(clk, reset, 1'b1, mem_to_reg_ex, mem_to_reg_mem);

dfrl_32 dfrl_32_alu_result(clk, reset, 1'b1, alu_result_ex, alu_result_mem);
dfrl_32 dfrl_32_write_data(clk, reset, 1'b1, write_data_ex, write_data_mem);

dfrl_5 dfrl_5_write_reg(clk, reset, 1'b1, write_reg_ex, write_reg_mem);

endmodule
