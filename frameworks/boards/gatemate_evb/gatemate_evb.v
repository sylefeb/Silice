/*

Copyright 2019, (C) Sylvain Lefebvre and contributors
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

`define GATEMATE_EVB 1
`define GATEMATE_A1  1
`default_nettype none
$$GATEMATE_EVB = 1
$$GATEMATE_A1  = 1
$$HARDWARE = 1
$$NUM_LEDS = 8
$$NUM_BTNS = 1
$$config['dualport_bram_supported'] = 'yes'
$$config['allow_deprecated_framework'] = 'no'
// declare package pins (has to match the hardware pin definition)
// pin.NAME = <WIDTH>
$$pin.leds       = 8
$$pin.btns       = 1

module top(
  %TOP_SIGNATURE%
  input  clk // 10 MHz
  );

/*
wire ready = 0;
reg [15:0] RST_d;
reg [15:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge clk) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 16'b111111111111111;
  end
end
*/

wire run_main;
assign run_main = 1'b1;

%WIRE_DECL%

wire [7:0] leds_n;
`define __alias_leds leds_n

M_main __main(
  .clock         (clk),
  .reset         (/*RST_q[0]*/1'b0),
   %MAIN_GLUE%
  .in_run        (run_main)
);

assign leds = ~leds_n;

endmodule
