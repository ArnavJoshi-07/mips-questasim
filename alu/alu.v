// op[3] inverts i0, op[2] inverts i1 (and supplies the carry-in for
// subtraction), op[1:0] selects the slice output:
//   0000 and   0001 or   0010 add   0110 sub   0111 slt   1100 nor
// The full adder fa is in library.v.

module alu_slice(input wire [3:0] op, input wire i0, i1, cin, less,
                 output wire o, cout);

wire a, b, t_and, t_or, t_sum;

assign a = i0 ^ op[3];
assign b = i1 ^ op[2];

fa fa_0(a, b, cin, t_sum, cout);

assign t_and = a & b;
assign t_or = a | b;

mux4 mux4_0({t_and, t_or, t_sum, less}, op[1], op[0], o);

endmodule


// The most significant slice also produces overflow and the "set" bit
// that slt routes back to bit 0. Using sum ^ overflow instead of the raw
// sign bit keeps slt correct when the subtraction overflows.
module alu_slice_msb(input wire [3:0] op, input wire i0, i1, cin, less,
                     output wire o, cout, set, overflow);

wire a, b, t_and, t_or, t_sum;

assign a = i0 ^ op[3];
assign b = i1 ^ op[2];

fa fa_0(a, b, cin, t_sum, cout);

assign t_and = a & b;
assign t_or = a | b;

mux4 mux4_0({t_and, t_or, t_sum, less}, op[1], op[0], o);

assign overflow = cin ^ cout;
assign set = t_sum ^ overflow;

endmodule


module alu(input wire [3:0] op,
           input wire [31:0] i0, i1,
           output wire [31:0] o,
           output wire zero, overflow);

wire [31:0] c;
wire set;

alu_slice alu_slice_i0(op, i0[0], i1[0], op[2], set, o[0], c[0]);

genvar k;

generate
    for (k = 1; k < 31; k = k + 1) begin : slices
        alu_slice alu_slice_i(op, i0[k], i1[k], c[k-1], 1'b0, o[k], c[k]);
    end
endgenerate

alu_slice_msb alu_slice_i31(op, i0[31], i1[31], c[30], 1'b0, o[31], c[31], set, overflow);

assign zero = ~|o;

endmodule
