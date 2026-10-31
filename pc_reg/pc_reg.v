// Program counter: a 32-bit register that loads pc_next on every rising edge
// while load is 1. The hazard unit drops load for one cycle to freeze the PC
// during a load-use stall. reset sets the PC to 0, where imem holds the
// first instruction.

module pc_reg(
    input wire clk, reset, load,
    input wire [31:0] pc_next,
    output wire [31:0] pc
);

dfrl_32 dfrl_32_0(clk, reset, load, pc_next, pc);

endmodule
