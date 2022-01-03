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
`define BARE 1

$$SIMULATION=1
$$BARE=1
$$NUM_LEDS=8
$$config['bram_wenable_width'] = '1'
$$config['dualport_bram_wenable0_width'] = 'data'
$$config['dualport_bram_wenable1_width'] = 'data'
$$config['simple_dualport_bram_wenable0_width'] = 'data'
$$config['simple_dualport_bram_wenable1_width'] = 'data'

module top(
  output [7:0] out_leds,
  input        clock
);

reg ready = 0;

always @(posedge clock) begin
  ready <= 1;
end

wire run_main;
assign run_main = 1'b1;

M_main __main(
  .clock(clock),
  .reset(~ready),
  .out_leds(out_leds),
  .in_run(run_main)
);

endmodule
