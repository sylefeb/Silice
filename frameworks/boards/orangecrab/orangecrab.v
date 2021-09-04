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
`default_nettype none
$$ORANGECRAB=1
$$HARDWARE=1
$$NUM_LEDS=3

module top(
  input  CLK, // 38.8 MHz
  // bare
  output [2:0] LED
  );

// input/output wires

wire [2:0]  __main_out_leds;

assign LED  = __main_out_leds;

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
  .clock         (CLK),
  .reset         (RST_q[0]),
  .in_run        (run_main),
  .out_leds      (__main_out_leds)
);

endmodule
