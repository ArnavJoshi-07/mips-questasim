module mux2(input wire i0, i1, j, output wire o);
    assign o = (j == 0) ? i0 : i1;
endmodule

module mux4(input wire [0:3] i, input wire j1, j0, output wire o);
    wire t0, t1;

    mux2 mux2_0(i[0], i[1], j0, t0);
    mux2 mux2_1(i[2], i[3], j0, t1);
    mux2 mux2_2(t0, t1, j1, o);
endmodule

module mux8(input wire [0:7] i, input wire j2, j1, j0, output wire o);
    wire t0, t1;

    mux4 mux4_0(i[0:3], j1, j0, t0);
    mux4 mux4_1(i[4:7], j1, j0, t1);
    mux2 mux2_0(t0, t1, j2, o);
endmodule

module demux2(input wire i, j, output wire o0, o1);
    assign o0 = (j == 0) ? i : 1'b0;
    assign o1 = (j == 1) ? i : 1'b0;
endmodule

module demux4(input wire i, j1, j0, output wire [0:3] o);
    wire t0, t1;

    demux2 demux2_0(i, j1, t0, t1);
    demux2 demux2_1(t0, j0, o[0], o[1]);
    demux2 demux2_2(t1, j0, o[2], o[3]);
endmodule

module demux8(input wire i, j2, j1, j0, output wire [0:7] o);
    wire t0, t1;

    demux2 demux2_0(i, j2, t0, t1);
    demux4 demux4_0(t0, j1, j0, o[0:3]);
    demux4 demux4_1(t1, j1, j0, o[4:7]);
endmodule

module df(input wire clk, in, output wire out);
    reg df_out;

    always @(posedge clk)
        df_out <= in;

    assign out = df_out;
endmodule

module dfr(input wire clk, reset, in, output wire out);
    wire reset_, df_in;

    not (reset_, reset);
    and (df_in, in, reset_);

    df df_0(clk, df_in, out);
endmodule

module dfrl(input wire clk, reset, load, in, output wire out);
    wire mux_out;

    mux2 mux2_0(out, in, load, mux_out);
    dfr dfr_0(clk, reset, mux_out, out);
endmodule

module fa(input wire i0, i1, cin, output wire sum, cout);
    wire t0, t1, t2;

    assign sum = i0 ^ i1 ^ cin;
    assign t0 = i0 & i1;
    assign t1 = i0 & cin;
    assign t2 = i1 & cin;
    assign cout = t0 | t1 | t2;
endmodule

// Ripple-carry adder for PC + 4 and the branch target. The carry out is
// dropped, so the sum wraps like a MIPS address.
module adder32(input wire [31:0] i0, i1, output wire [31:0] o);
    wire [31:0] c;

    fa fa_0(i0[0], i1[0], 1'b0, o[0], c[0]);

    genvar k;

    generate
        for (k = 1; k < 32; k = k + 1) begin : bits
            fa fa_k(i0[k], i1[k], c[k-1], o[k], c[k]);
        end
    endgenerate
endmodule

// Word-wide multiplexers: one mux2 or mux4 per bit, all sharing the select.
// mux2_5 picks the destination register (rt or rd).
module mux2_5(input wire [4:0] i0, i1, input wire j, output wire [4:0] o);
    genvar k;

    generate
        for (k = 0; k < 5; k = k + 1) begin : bits
            mux2 mux2_k(i0[k], i1[k], j, o[k]);
        end
    endgenerate
endmodule

module mux2_32(input wire [31:0] i0, i1, input wire j, output wire [31:0] o);
    genvar k;

    generate
        for (k = 0; k < 32; k = k + 1) begin : bits
            mux2 mux2_k(i0[k], i1[k], j, o[k]);
        end
    endgenerate
endmodule

// {j1, j0} = 00 picks i0, 01 i1, 10 i2, 11 i3
module mux4_32(input wire [31:0] i0, i1, i2, i3, input wire j1, j0,
               output wire [31:0] o);
    genvar k;

    generate
        for (k = 0; k < 32; k = k + 1) begin : bits
            mux4 mux4_k({i0[k], i1[k], i2[k], i3[k]}, j1, j0, o[k]);
        end
    endgenerate
endmodule

// 32-bit register on the rising edge, for the PC and the pipeline registers.
// The register file uses the falling-edge dfrl_neg_32 instead.
module dfrl_32(
    input wire clk, reset, load,
    input wire [31:0] in,
    output wire [31:0] out
);
    genvar k;

    generate
        for (k = 0; k < 32; k = k + 1) begin : bits
            dfrl dfrl_k(clk, reset, load, in[k], out[k]);
        end
    endgenerate
endmodule

// 5-bit register for the register numbers (rs, rt, rd) the pipeline carries.
module dfrl_5(
    input wire clk, reset, load,
    input wire [4:0] in,
    output wire [4:0] out
);
    genvar k;

    generate
        for (k = 0; k < 5; k = k + 1) begin : bits
            dfrl dfrl_k(clk, reset, load, in[k], out[k]);
        end
    endgenerate
endmodule
