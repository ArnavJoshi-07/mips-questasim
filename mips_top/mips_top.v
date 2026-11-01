// Five-stage pipelined MIPS processor: IF, ID, EX, MEM, WB, separated by the
// IF/ID, ID/EX, EX/MEM and MEM/WB registers. It uses the same datapath blocks
// as single_cycle/mips_single.v. Signal names end in the stage they belong to
// (_if, _id, _ex, _mem, _wb).
//
// Data hazards between ALU instructions are handled by forwarding: the
// forwarding unit compares rs and rt in EX with the destinations in EX/MEM
// and MEM/WB, and two 4-input muxes in front of the ALU pick the newest
// value. An instruction 3 or more behind its producer reads the register
// file, which is written on the falling edge before ID reads it.
//
// Load-use hazards are handled by the hazard unit: when the instruction in
// ID reads the register a lw in EX is loading, it stalls one cycle (PC and
// IF/ID hold, ID/EX gets a bubble), after which the loaded value is
// forwarded from MEM/WB.
//
// There are no branch flushes yet, so the program must still avoid the
// control hazards itself (see programs/fibonacci_stall.asm):
//   - beq is resolved in EX: the two instructions behind it are fetched
//     and executed whether or not it is taken;
//   - j is resolved in ID: the instruction behind it is always executed.
// flush_if_id is where branch flushing will connect; for now it is tied off.
//
// Next PC: a taken branch in EX is older than a jump in ID, so it has the
// last word.

module mips_top(
    input wire clk, reset,
    output wire [31:0] pc, instr
);

// Hazard control. stall comes from the hazard unit, after ID/EX.
wire stall, flush_if_id, flush_id_ex;
wire load_if;

assign flush_if_id = 1'b0;  // tied off until branch flushing is added

not (load_if, stall);       // a stall freezes the PC and IF/ID

// IF
wire [31:0] pc_if, instr_if, pc_plus4_if, pc_jump, pc_next;

// ID
wire [31:0] pc_plus4_id, instr_id, read_data_a_id, read_data_b_id, imm_ext_id, jump_addr_id;
wire reg_dst_id, alu_src_id, mem_to_reg_id, reg_write_id, mem_read_id, mem_write_id;
wire branch_id, jump_id;
wire [1:0] alu_op_id;

// EX
wire [31:0] pc_plus4_ex, read_data_a_ex, read_data_b_ex, imm_ext_ex;
wire [31:0] alu_a_ex, fwd_b_ex, alu_b_ex, alu_result_ex, branch_target_ex;
wire reg_dst_ex, alu_src_ex, mem_read_ex, mem_write_ex, branch_ex, reg_write_ex, mem_to_reg_ex;
wire [1:0] alu_op_ex;
wire [3:0] alu_ctrl_ex;
wire [4:0] rs_ex, rt_ex, rd_ex, write_reg_ex;
wire [1:0] forward_a_ex, forward_b_ex;
wire zero_ex, overflow_ex, pc_src_ex;

// MEM
wire [31:0] alu_result_mem, write_data_mem, mem_data_mem;
wire mem_write_mem, reg_write_mem, mem_to_reg_mem;
wire [4:0] write_reg_mem;

// WB
wire [31:0] mem_data_wb, alu_result_wb, write_data_wb;
wire reg_write_wb, mem_to_reg_wb;
wire [4:0] write_reg_wb;

assign pc = pc_if;
assign instr = instr_if;


// ---------------------------------------------------------------- IF
pc_reg pc_reg_0(clk, reset, load_if, pc_next, pc_if);
imem imem_0(pc_if, instr_if);
adder32 adder32_pc4(pc_if, 32'd4, pc_plus4_if);

// Next PC: PC + 4, else a jump decoded in ID, else a taken branch in EX
mux2_32 mux2_32_jump(pc_plus4_if, jump_addr_id, jump_id, pc_jump);
mux2_32 mux2_32_pc_src(pc_jump, branch_target_ex, pc_src_ex, pc_next);

if_id_reg if_id_reg_0(clk, reset, load_if, flush_if_id,
                      pc_plus4_if, instr_if, pc_plus4_id, instr_id);


// ---------------------------------------------------------------- ID
control_unit control_unit_0(instr_id[31:26], reg_dst_id, alu_src_id, mem_to_reg_id,
                            reg_write_id, mem_read_id, mem_write_id, branch_id,
                            jump_id, alu_op_id);
reg_file reg_file_0(clk, reset, reg_write_wb, instr_id[25:21], instr_id[20:16],
                    write_reg_wb, write_data_wb, read_data_a_id, read_data_b_id);
sign_extend sign_extend_0(instr_id[15:0], imm_ext_id);

// Jump target = {PC + 4 [31:28], addr, 00}
assign jump_addr_id = {pc_plus4_id[31:28], instr_id[25:0], 2'b00};

id_ex_reg id_ex_reg_0(
    .clk(clk), .reset(reset), .load(1'b1), .flush(flush_id_ex),
    .reg_dst_id(reg_dst_id), .alu_src_id(alu_src_id), .alu_op_id(alu_op_id),
    .mem_read_id(mem_read_id), .mem_write_id(mem_write_id), .branch_id(branch_id),
    .reg_write_id(reg_write_id), .mem_to_reg_id(mem_to_reg_id),
    .pc_plus4_id(pc_plus4_id), .read_data_a_id(read_data_a_id),
    .read_data_b_id(read_data_b_id), .imm_ext_id(imm_ext_id),
    .rs_id(instr_id[25:21]), .rt_id(instr_id[20:16]), .rd_id(instr_id[15:11]),
    .reg_dst_ex(reg_dst_ex), .alu_src_ex(alu_src_ex), .alu_op_ex(alu_op_ex),
    .mem_read_ex(mem_read_ex), .mem_write_ex(mem_write_ex), .branch_ex(branch_ex),
    .reg_write_ex(reg_write_ex), .mem_to_reg_ex(mem_to_reg_ex),
    .pc_plus4_ex(pc_plus4_ex), .read_data_a_ex(read_data_a_ex),
    .read_data_b_ex(read_data_b_ex), .imm_ext_ex(imm_ext_ex),
    .rs_ex(rs_ex), .rt_ex(rt_ex), .rd_ex(rd_ex)
);

// Load-use: a lw in EX whose destination (rt) is read by the instruction in
// ID. The stall holds PC and IF/ID and turns the next ID/EX into a bubble.
hazard_unit hazard_unit_0(mem_read_ex, rt_ex, instr_id[25:21], instr_id[20:16], stall);
assign flush_id_ex = stall;


// ---------------------------------------------------------------- EX
alu_control alu_control_0(alu_op_ex, imm_ext_ex[5:0], alu_ctrl_ex);

// Forwarding: 00 register file, 01 MEM/WB, 10 EX/MEM
forwarding_unit forwarding_unit_0(rs_ex, rt_ex, write_reg_mem, write_reg_wb,
                                  reg_write_mem, reg_write_wb,
                                  forward_a_ex, forward_b_ex);
mux4_32 mux4_32_fwd_a(read_data_a_ex, write_data_wb, alu_result_mem, 32'h0,
                      forward_a_ex[1], forward_a_ex[0], alu_a_ex);
mux4_32 mux4_32_fwd_b(read_data_b_ex, write_data_wb, alu_result_mem, 32'h0,
                      forward_b_ex[1], forward_b_ex[0], fwd_b_ex);

// The forwarded rt value goes both to alu_src (R-type, beq) and to EX/MEM as
// sw's store data. For lw and addi rt is the destination, so a match there
// is harmless: alu_src picks the immediate.
mux2_32 mux2_32_alu_src(fwd_b_ex, imm_ext_ex, alu_src_ex, alu_b_ex);
alu alu_0(alu_ctrl_ex, alu_a_ex, alu_b_ex, alu_result_ex, zero_ex, overflow_ex);
mux2_5 mux2_5_reg_dst(rt_ex, rd_ex, reg_dst_ex, write_reg_ex);

// Branch target = PC + 4 + (imm << 2); taken when beq's operands are equal
adder32 adder32_branch(pc_plus4_ex, {imm_ext_ex[29:0], 2'b00}, branch_target_ex);
and (pc_src_ex, branch_ex, zero_ex);

ex_mem_reg ex_mem_reg_0(clk, reset,
                        mem_write_ex, reg_write_ex, mem_to_reg_ex,
                        alu_result_ex, fwd_b_ex, write_reg_ex,
                        mem_write_mem, reg_write_mem, mem_to_reg_mem,
                        alu_result_mem, write_data_mem, write_reg_mem);


// ---------------------------------------------------------------- MEM
dmem dmem_0(clk, mem_write_mem, alu_result_mem, write_data_mem, mem_data_mem);

mem_wb_reg mem_wb_reg_0(clk, reset,
                        reg_write_mem, mem_to_reg_mem, mem_data_mem, alu_result_mem,
                        write_reg_mem,
                        reg_write_wb, mem_to_reg_wb, mem_data_wb, alu_result_wb,
                        write_reg_wb);


// ---------------------------------------------------------------- WB
mux2_32 mux2_32_mem_to_reg(alu_result_wb, mem_data_wb, mem_to_reg_wb, write_data_wb);

endmodule
