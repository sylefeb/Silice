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
`define YOSYS   1
`define SILIXEL 1
`default_nettype none
$$SIMULATION  = 1
$$SILIXEL     = 1
$$NUM_LEDS    = 8
$$color_depth = 6
$$color_max   = 63

$$pin.leds      = 8

$$if VGA then
$$pin.video_r   = 6
$$pin.video_g   = 6
$$pin.video_b   = 6
$$pin.video_hs  = 1
$$pin.video_vs  = 1
$$end

$$if HDMI then
$$pin.gpdi_dp   = 4
$$end

// silixel_oddr: double data rate output
//   D0, D1 are captured on C posedge
//   Q outputs D0 on C high, D1 on C low
(* blackbox *)
module silixel_oddr(
  input  C,
  input  D0,
  input  D1,
  output Q
);
endmodule


module top(
  // LED outputs
  %TOP_SIGNATURE%
  input clock
);

  reg reset = 1;

  always @(posedge clock) begin
    if (reset) begin
      reset <= 0;
    end
  end

  %WIRE_DECL%

  M_main __main(
    .clock        (clock),
    .reset        (reset),
    %MAIN_GLUE%
    .in_run       (~reset)
  );

endmodule
