// Turns the main decoder's alu_op and the instruction's funct field into
// the 4-bit ALU operation (see alu/alu.v):
//   alu_op 00 (lw, sw, addi)  -> 0010 add
//   alu_op 01 (beq)           -> 0110 sub
//   alu_op 10 (R-type)        -> from funct: add 0010, sub 0110,
//                                and 0000, or 0001, slt 0111
// The gate equations are the ones from Patterson and Hennessy, which treat
// alu_op 11 and funct values outside this list as don't-cares.

module alu_control(input wire [1:0] alu_op,
                   input wire [5:0] funct,
                   output wire [3:0] op);

assign op[3] = 1'b0;
assign op[2] = alu_op[0] | (alu_op[1] & funct[1]);
assign op[1] = ~alu_op[1] | ~funct[2];
assign op[0] = alu_op[1] & (funct[3] | funct[0]);

endmodule
