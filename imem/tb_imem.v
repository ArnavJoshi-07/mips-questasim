module tb;
reg [31:0] addr;
wire [31:0] instr;
integer errors, checks, n;

// fibonacci.hex as it should appear in memory
reg [31:0] expected [0:17];

imem imem_0(addr, instr);

task check;
    input [31:0] want;
    input [8*24:1] what;
begin
    checks = checks + 1;
    if (instr !== want) begin
        $display("FAIL: %0s: addr=%h instr=%h, expected %h", what, addr, instr, want);
        errors = errors + 1;
    end
end
endtask

initial begin
    $dumpfile("tb_imem.vcd");
    $dumpvars(0, tb);
end

initial begin
    errors = 0; checks = 0;
    expected[0]  = 32'h20100000; expected[1]  = 32'h20080000;
    expected[2]  = 32'h20090001; expected[3]  = 32'h200b000c;
    expected[4]  = 32'hae080000; expected[5]  = 32'hae090004;
    expected[6]  = 32'h22100008; expected[7]  = 32'h200c0002;
    expected[8]  = 32'h118b0007; expected[9]  = 32'h8e0dfff8;
    expected[10] = 32'h8e0efffc; expected[11] = 32'h01ae7820;
    expected[12] = 32'hae0f0000; expected[13] = 32'h22100004;
    expected[14] = 32'h218c0001; expected[15] = 32'h08000008;
    expected[16] = 32'h8e02fffc; expected[17] = 32'h08000011;

    // Memory starts empty without +PROGRAM
    addr = 32'h0;
    #1 check(32'h0, "empty before load");

    // Load the program the way the top-level testbench will. Done after
    // time 0 so it lands after imem clears its words.
    $readmemh("../programs/fibonacci.hex", imem_0.mem, 0, 17);

    // Walkthrough: fetch every instruction in order, as IF would
$monitor("time=%0t addr=%h instr=%h", $time, addr, instr);
    for (n = 0; n < 18; n = n + 1) begin
        addr = 4 * n;
        #10 check(expected[n], "program word");
    end
    $monitoroff;

    // Words after the program stay 0
    addr = 32'h48;
    #1 check(32'h0, "word after program");
    addr = 32'h3fc;
    #1 check(32'h0, "last word");

    // The low two address bits are ignored
    for (n = 0; n < 4; n = n + 1) begin
        addr = 32'h2c + n;
        #1 check(expected[11], "low bits ignored");
    end

    // Addresses wrap every 1 KB
    addr = 32'h400;
    #1 check(expected[0], "wrap 0x400");
    addr = 32'h1000_0020;
    #1 check(expected[8], "wrap high address");

    if (errors == 0) $display("PASS: tb_imem (%0d checks)", checks);
    else             $display("FAIL: tb_imem (%0d of %0d checks failed)", errors, checks);
    $finish;
end
endmodule
