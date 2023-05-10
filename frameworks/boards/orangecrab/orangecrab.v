/*

Copyright 2019, (C) Sylvain Lefebvre, Gwenhael Goavec-Mero and contributors
List contributors with: git shortlog -n -s -- <filename>

MIT license

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

(header_2_M)

*/
`define ORANGECRAB 1
`define ECP5       1
`default_nettype none
$$ORANGECRAB=1
$$ECP5=1
$$HARDWARE=1
$$NUM_LEDS=3

module top(
  // bare
  output [2:0] LED,
  output       RST,
  // feather
`ifdef FEATHER
  inout [13:0] G,
  inout [5:0]  A,
  output       SCK,
  output       SDA,
  output       SCL,
  output       MOSI,
  input        MISO,
`endif
  // clock
  input  CLK // 38.8 MHz
  );

// input/output wires

wire [2:0]  __main_out_leds;

assign LED  = __main_out_leds;
assign RST  = 1'b1; // hold FPGA reset high

// reset

reg ready = 0;

reg [15:0] RST_d;
reg [15:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge CLK) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 16'b1111111111111111;
  end
end

// main

wire   run_main;
assign run_main = 1'b1;

M_main __main(
  .reset         (RST_q[0]),
  .in_run        (run_main),
  .out_leds      (__main_out_leds),
`ifdef FEATHER
  .inout_G       (G),
  .inout_A       (A),
  .out_sck       (SCK),
  .out_mosi      (MOSI),
  .in_miso       (MISO),
  .out_sda       (SDA),
  .out_scl       (SCL),
`endif
  .clock         (CLK)
);

endmodule
