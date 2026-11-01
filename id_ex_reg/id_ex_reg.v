// ID/EX pipeline register: carries the decoded control signals, the two
// register operands, the sign-extended immediate, PC + 4 (for the branch
// target) and the register numbers into the execute stage.
//
// Control signals, grouped by the stage that uses them:
//   EX   reg_dst, alu_src, alu_op[1:0]
//   MEM  mem_read, mem_write, branch   (branch is resolved in EX here)
//   WB   reg_write, mem_to_reg
// mem_read is not needed by dmem, but the hazard unit uses it to spot a load
// in EX. rs is carried for the forwarding unit. funct is imm[5:0].
//
//   load  = 0  holds the current contents
//   flush = 1  clears every field on the next rising edge. With all control
//              signals 0 the instruction writes nothing, so this inserts a
//              bubble (load-use stall) or squashes a wrong-path instruction
//              (taken branch).

module id_ex_reg(
    input wire clk, reset, load, flush,

    input wire reg_dst_id, alu_src_id,
    input wire [1:0] alu_op_id,
    input wire mem_read_id, mem_write_id, branch_id,
    input wire reg_write_id, mem_to_reg_id,
    input wire [31:0] pc_plus4_id, read_data_a_id, read_data_b_id, imm_ext_id,
    input wire [4:0] rs_id, rt_id, rd_id,

    output wire reg_dst_ex, alu_src_ex,
    output wire [1:0] alu_op_ex,
    output wire mem_read_ex, mem_write_ex, branch_ex,
    output wire reg_write_ex, mem_to_reg_ex,
    output wire [31:0] pc_plus4_ex, read_data_a_ex, read_data_b_ex, imm_ext_ex,
    output wire [4:0] rs_ex, rt_ex, rd_ex
);

wire clear;
wire [8:0] ctrl_id, ctrl_ex;

or (clear, reset, flush);

assign ctrl_id = {reg_dst_id, alu_src_id, alu_op_id,
                  mem_read_id, mem_write_id, branch_id,
                  reg_write_id, mem_to_reg_id};

genvar k;

generate
    for (k = 0; k < 9; k = k + 1) begin : ctrl
        dfrl dfrl_k(clk, clear, load, ctrl_id[k], ctrl_ex[k]);
    end
endgenerate

assign {reg_dst_ex, alu_src_ex, alu_op_ex,
        mem_read_ex, mem_write_ex, branch_ex,
        reg_write_ex, mem_to_reg_ex} = ctrl_ex;

dfrl_32 dfrl_32_pc_plus4(clk, clear, load, pc_plus4_id, pc_plus4_ex);
dfrl_32 dfrl_32_read_data_a(clk, clear, load, read_data_a_id, read_data_a_ex);
dfrl_32 dfrl_32_read_data_b(clk, clear, load, read_data_b_id, read_data_b_ex);
dfrl_32 dfrl_32_imm_ext(clk, clear, load, imm_ext_id, imm_ext_ex);

dfrl_5 dfrl_5_rs(clk, clear, load, rs_id, rs_ex);
dfrl_5 dfrl_5_rt(clk, clear, load, rt_id, rt_ex);
dfrl_5 dfrl_5_rd(clk, clear, load, rd_id, rd_ex);

endmodule
