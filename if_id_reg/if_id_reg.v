// IF/ID pipeline register: carries the fetched instruction and PC + 4 into
// the decode stage.
//
//   load  = 0  holds the current contents (load-use stall, together with
//              freezing the PC)
//   flush = 1  clears it on the next rising edge, turning the instruction
//              into a nop (00000000 = sll $zero, $zero, 0); used when a
//              taken branch or jump makes the fetched instruction wrong
//
// flush is ORed into the synchronous reset of the dfrl flip-flops, so it
// wins over load, just as reset does.

module if_id_reg(
    input wire clk, reset, load, flush,
    input wire [31:0] pc_plus4_if, instr_if,
    output wire [31:0] pc_plus4_id, instr_id
);

wire clear;

or (clear, reset, flush);

dfrl_32 dfrl_32_pc_plus4(clk, clear, load, pc_plus4_if, pc_plus4_id);
dfrl_32 dfrl_32_instr(clk, clear, load, instr_if, instr_id);

endmodule
