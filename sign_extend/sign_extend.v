// Copies bit 15 of the immediate into the upper 16 bits, so negative
// offsets (e.g. lw $t0, -4($sp)) stay negative as 32-bit values.

module sign_extend(input wire [15:0] i, output wire [31:0] o);

assign o = {{16{i[15]}}, i};

endmodule
