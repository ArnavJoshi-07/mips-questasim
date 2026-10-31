// Instruction memory: 256 words (1 KB), read-only, read by the IF stage only.
// Together with dmem this gives the Harvard organisation, so IF and MEM never
// compete for a memory port.
//
// Unlike the rest of the datapath this is a behavioural array rather than
// library.v flip-flops: 8192 flip-flops plus a 256-way decoder would be slow to
// simulate and is not how real memories are built.
//
// Every word starts as 0. A program is loaded at time 0 with
//   vvp test +PROGRAM=../programs/fibonacci.hex
// The read is combinational. addr is a byte address; the low two bits are
// ignored (instructions are word-aligned) and addresses above 1 KB wrap.

module imem(input wire [31:0] addr, output wire [31:0] instr);
    reg [31:0] mem [0:255];
    reg [8*256:1] program;
    integer w;

    initial begin
        for (w = 0; w < 256; w = w + 1)
            mem[w] = 32'h0;
        if ($value$plusargs("PROGRAM=%s", program))
            $readmemh(program, mem);
    end

    assign instr = mem[addr[9:2]];
endmodule
