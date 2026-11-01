// MEM/WB pipeline register: carries the loaded word, the ALU result, the
// destination register and the two write-back control signals.
//
// Like EX/MEM it is never stalled or flushed, so it only has a reset.

module mem_wb_reg(
    input wire clk, reset,
    input wire reg_write_mem, mem_to_reg_mem,
    input wire [31:0] mem_data_mem, alu_result_mem,
    input wire [4:0] write_reg_mem,
    output wire reg_write_wb, mem_to_reg_wb,
    output wire [31:0] mem_data_wb, alu_result_wb,
    output wire [4:0] write_reg_wb
);

dfrl dfrl_reg_write(clk, reset, 1'b1, reg_write_mem, reg_write_wb);
dfrl dfrl_mem_to_reg(clk, reset, 1'b1, mem_to_reg_mem, mem_to_reg_wb);

dfrl_32 dfrl_32_mem_data(clk, reset, 1'b1, mem_data_mem, mem_data_wb);
dfrl_32 dfrl_32_alu_result(clk, reset, 1'b1, alu_result_mem, alu_result_wb);

dfrl_5 dfrl_5_write_reg(clk, reset, 1'b1, write_reg_mem, write_reg_wb);

endmodule
