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
`define MINIMAL 1
`define COLOR_DEPTH       6

$$SIMULATION=1
$$MINIMAL=1
$$NUM_LEDS=8
$$config['bram_wenable_width'] = '1'
$$config['dualport_bram_wenable0_width'] = 'data'
$$config['dualport_bram_wenable1_width'] = 'data'
$$config['simple_dualport_bram_wenable0_width'] = 'data'
$$config['simple_dualport_bram_wenable1_width'] = 'data'
$$color_depth = 6
$$color_max   = 63

module top(
`ifdef VGA
  // VGA
  output out_video_clock,
  output reg [`COLOR_DEPTH-1:0] out_video_r,
  output reg [`COLOR_DEPTH-1:0] out_video_g,
  output reg [`COLOR_DEPTH-1:0] out_video_b,
  output out_video_hs,
  output out_video_vs,
`endif
  // basic
  output [7:0] out_leds,
  input        clock
);

reg [2:0] ready = 3'b111;

always @(posedge clock) begin
  ready <= ready >> 1;
end

wire run_main;
assign run_main = 1'b1;

M_main __main(
  .clock(clock),
  .reset(ready[0]),
  .out_leds(out_leds),
`ifdef VGA
  .out_video_clock(out_video_clock),
  .out_video_r(out_video_r),
  .out_video_g(out_video_g),
  .out_video_b(out_video_b),
  .out_video_hs(out_video_hs),
  .out_video_vs(out_video_vs),
`endif
  .in_run(run_main)
);

endmodule
