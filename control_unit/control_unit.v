// Main decoder. The first stage recognises each supported opcode with an
// AND of the six opcode bits; the second stage ORs those into the control
// signals, as in the Patterson and Hennessy PLA. Unsupported opcodes set
// every signal to 0, so they behave like a nop.
//
//            reg_dst alu_src mem_to_reg reg_write mem_read mem_write branch jump alu_op
//   R-type      1       0        0          1         0        0        0     0    10
//   lw          0       1        1          1         1        0        0     0    00
//   sw          0       1        0          0         0        1        0     0    00
//   beq         0       0        0          0         0        0        1     0    01
//   addi        0       1        0          1         0        0        0     0    00
//   j           0       0        0          0         0        0        0     1    00

module control_unit(input wire [5:0] opcode,
                    output wire reg_dst, alu_src, mem_to_reg, reg_write,
                    output wire mem_read, mem_write, branch, jump,
                    output wire [1:0] alu_op);

wire r_format, lw, sw, beq, addi, j;

assign r_format = ~opcode[5] & ~opcode[4] & ~opcode[3] & ~opcode[2] & ~opcode[1] & ~opcode[0]; // 000000
assign lw       =  opcode[5] & ~opcode[4] & ~opcode[3] & ~opcode[2] &  opcode[1] &  opcode[0]; // 100011
assign sw       =  opcode[5] & ~opcode[4] &  opcode[3] & ~opcode[2] &  opcode[1] &  opcode[0]; // 101011
assign beq      = ~opcode[5] & ~opcode[4] & ~opcode[3] &  opcode[2] & ~opcode[1] & ~opcode[0]; // 000100
assign addi     = ~opcode[5] & ~opcode[4] &  opcode[3] & ~opcode[2] & ~opcode[1] & ~opcode[0]; // 001000
assign j        = ~opcode[5] & ~opcode[4] & ~opcode[3] & ~opcode[2] &  opcode[1] & ~opcode[0]; // 000010

assign reg_dst    = r_format;
assign alu_src    = lw | sw | addi;
assign mem_to_reg = lw;
assign reg_write  = r_format | lw | addi;
assign mem_read   = lw;
assign mem_write  = sw;
assign branch     = beq;
assign jump       = j;
assign alu_op[1]  = r_format;
assign alu_op[0]  = beq;

endmodule
