// Falling-edge versions of df, dfr and dfrl from library.v. The register
// file writes on the falling edge so that a value written in WB can be
// read by ID later in the same clock cycle.

module df_neg(input wire clk, in, output wire out);
    reg df_out;

    always @(negedge clk)
        df_out <= in;

    assign out = df_out;
endmodule

module dfr_neg(input wire clk, reset, in, output wire out);
    wire reset_, df_in;

    not (reset_, reset);
    and (df_in, in, reset_);

    df_neg df_0(clk, df_in, out);
endmodule

module dfrl_neg(input wire clk, reset, load, in, output wire out);
    wire mux_out;

    mux2 mux2_0(out, in, load, mux_out);
    dfr_neg dfr_0(clk, reset, mux_out, out);
endmodule


module dfrl_neg_32(
    input wire clk, reset, load,
    input wire [31:0] in,
    output wire [31:0] out
);

genvar k;

generate
    for (k = 0; k < 32; k = k + 1) begin : bits
        dfrl_neg dfrl_neg_k(clk, reset, load, in[k], out[k]);
    end
endgenerate

endmodule


module mux32(input wire [0:31] i, input wire j4, j3, j2, j1, j0, output wire o);
    wire [0:3] t;

    mux8 mux8_0(i[0:7],   j2, j1, j0, t[0]);
    mux8 mux8_1(i[8:15],  j2, j1, j0, t[1]);
    mux8 mux8_2(i[16:23], j2, j1, j0, t[2]);
    mux8 mux8_3(i[24:31], j2, j1, j0, t[3]);
    mux4 mux4_0(t, j4, j3, o);
endmodule

module demux32(input wire i, j4, j3, j2, j1, j0, output wire [0:31] o);
    wire [0:3] t;

    demux4 demux4_0(i, j4, j3, t);
    demux8 demux8_0(t[0], j2, j1, j0, o[0:7]);
    demux8 demux8_1(t[1], j2, j1, j0, o[8:15]);
    demux8 demux8_2(t[2], j2, j1, j0, o[16:23]);
    demux8 demux8_3(t[3], j2, j1, j0, o[24:31]);
endmodule


// i holds the 32 registers back to back: register r is i[32*r +: 32].
// Bit k of the output picks bit k of register j.
module mux32_32(
    input wire [1023:0] i,
    input wire [4:0] j,
    output wire [31:0] o
);

genvar k, r;

generate
    for (k = 0; k < 32; k = k + 1) begin : bits
        wire [0:31] col;

        for (r = 0; r < 32; r = r + 1) begin : regs
            assign col[r] = i[32*r + k];
        end

        mux32 mux32_k(col, j[4], j[3], j[2], j[1], j[0], o[k]);
    end
endgenerate

endmodule


module reg_file(
    input wire clk, reset, wr,
    input wire [4:0] rd_addr_a, rd_addr_b, wr_addr,
    input wire [31:0] d_in,
    output wire [31:0] d_out_a, d_out_b
);

wire [0:31] load;
wire [1023:0] dout;

// $zero is not a real register: it always reads as 0 and writes to it are dropped
assign dout[31:0] = 32'b0;

genvar r;

generate
    for (r = 1; r < 32; r = r + 1) begin : regs
        dfrl_neg_32 dfrl_neg_32_r(clk, reset, load[r], d_in, dout[32*r +: 32]);
    end
endgenerate

demux32 demux32_0(
    wr,
    wr_addr[4], wr_addr[3], wr_addr[2], wr_addr[1], wr_addr[0],
    load
);

mux32_32 mux32_32_a(dout, rd_addr_a, d_out_a);
mux32_32 mux32_32_b(dout, rd_addr_b, d_out_b);

endmodule
