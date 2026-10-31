// Data memory: 256 words (1 KB), read and written by the MEM stage only.
// Together with imem this gives the Harvard organisation, so IF and MEM never
// compete for a memory port.
//
// Unlike the rest of the datapath this is a behavioural array rather than
// library.v flip-flops: 8192 flip-flops plus a 256-way decoder would be slow to
// simulate and is not how real memories are built.
//
// Every word starts as 0. Initial data can be loaded at time 0 with
//   vvp test +DATA=../programs/<name>_data.hex
// sw writes on the rising edge when mem_write is 1. lw reads combinationally,
// so the value is ready within the MEM stage and is latched into MEM/WB on
// the next rising edge. addr is a byte address; the low two bits are ignored
// (only word-aligned lw and sw are supported) and addresses above 1 KB wrap.

module dmem(
    input wire clk, mem_write,
    input wire [31:0] addr, write_data,
    output wire [31:0] read_data
);
    reg [31:0] mem [0:255];
    reg [8*256:1] data;
    integer w;

    initial begin
        for (w = 0; w < 256; w = w + 1)
            mem[w] = 32'h0;
        if ($value$plusargs("DATA=%s", data))
            $readmemh(data, mem);
    end

    always @(posedge clk)
        if (mem_write)
            mem[addr[9:2]] <= write_data;

    assign read_data = mem[addr[9:2]];
endmodule
