`timescale 1ns/1ps

// Checks that the build and test flow works end to end.
// Delete this once the first real unit test (tb_alu.v) exists.
module tb_smoke;
  reg  [31:0] a, b;
  wire [31:0] sum = a + b;
  integer errors;

  initial begin
    $dumpfile("build/tb_smoke.vcd");
    $dumpvars(0, tb_smoke);
    errors = 0;

    a = 32'd2;          b = 32'd3;          #1;
    if (sum !== 32'd5) begin
      $display("FAIL: 2 + 3 = %0d", sum); errors = errors + 1;
    end

    a = 32'hFFFF_FFFF;  b = 32'd1;          #1;
    if (sum !== 32'd0) begin
      $display("FAIL: wraparound gave %h", sum); errors = errors + 1;
    end

    if (errors == 0) $display("PASS: tb_smoke");
    else             $display("FAIL: tb_smoke (%0d errors)", errors);
    $finish;
  end
endmodule
