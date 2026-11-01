// Single-cycle reference processor. Every instruction is fetched, decoded,
// executed and written back in one clock cycle, using the same datapath
// blocks the pipeline will use. It gives the pipelined core a known-good
// result and a CPI of 1.0 to compare against.
//
// Clocking: the PC and dmem update on the rising edge, but reg_file writes
// on the FALLING edge (so the pipeline can write in WB and read in ID in the
// same cycle). Here that half-cycle write is still correct:
//   - an instruction's operands are read and its result written back to the
//     register file at the falling edge, half way through its cycle;
//   - after that write, a source register may change (e.g. addi $s0, $s0, 8
//     reads its own result back), so rs/rt, the ALU result and d_in change
//     in the second half of the cycle and no longer match the instruction;
//   - that is harmless, because the only state updated at the next rising
//     edge comes from sw (dmem), beq and j (PC), and none of them write a
//     register, so their operands are stable for the whole cycle. For every
//     other instruction the rising edge only loads PC + 4.
// Look at datapath signals before the falling edge, or at the register file
// itself at the rising edge; the testbench trace does the latter.

module mips_single(
    input wire clk, reset,
    output wire [31:0] pc, instr
);

wire reg_dst, alu_src, mem_to_reg, reg_write, mem_read, mem_write, branch, jump;
wire [1:0] alu_op;
wire [3:0] alu_ctrl;
wire [4:0] write_reg;
wire [31:0] read_data_a, read_data_b, imm_ext, alu_b, alu_result, mem_data, write_data;
wire zero, overflow;
wire pc_src;
wire [31:0] pc_plus4, branch_target, jump_addr, pc_branch, pc_next;

// Fetch
pc_reg pc_reg_0(clk, reset, 1'b1, pc_next, pc);
imem imem_0(pc, instr);
adder32 adder32_pc4(pc, 32'd4, pc_plus4);

// Decode
control_unit control_unit_0(instr[31:26], reg_dst, alu_src, mem_to_reg, reg_write,
                            mem_read, mem_write, branch, jump, alu_op);
mux2_5 mux2_5_reg_dst(instr[20:16], instr[15:11], reg_dst, write_reg);
reg_file reg_file_0(clk, reset, reg_write, instr[25:21], instr[20:16], write_reg,
                    write_data, read_data_a, read_data_b);
sign_extend sign_extend_0(instr[15:0], imm_ext);

// Execute
alu_control alu_control_0(alu_op, instr[5:0], alu_ctrl);
mux2_32 mux2_32_alu_src(read_data_b, imm_ext, alu_src, alu_b);
alu alu_0(alu_ctrl, read_data_a, alu_b, alu_result, zero, overflow);

// Memory
dmem dmem_0(clk, mem_write, alu_result, read_data_b, mem_data);

// Write-back
mux2_32 mux2_32_mem_to_reg(alu_result, mem_data, mem_to_reg, write_data);

// Next PC: branch target = PC + 4 + (imm << 2), jump = {PC + 4 [31:28], addr, 00}
adder32 adder32_branch(pc_plus4, {imm_ext[29:0], 2'b00}, branch_target);
and (pc_src, branch, zero);
mux2_32 mux2_32_pc_src(pc_plus4, branch_target, pc_src, pc_branch);
assign jump_addr = {pc_plus4[31:28], instr[25:0], 2'b00};
mux2_32 mux2_32_jump(pc_branch, jump_addr, jump, pc_next);

endmodule
