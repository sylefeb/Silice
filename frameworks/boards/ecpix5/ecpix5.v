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

`define ECPIX5 1
`define ECP5   1
`default_nettype none
$$ECPIX5   = 1
$$ECP5     = 1
$$HARDWARE = 1
$$NUM_LEDS = 12
$$color_depth=6
$$color_max  =63
// config
$$config['dualport_bram_supported'] = 'yes'
// declare package pins (has to match the hardware pin definition)
// pin.NAME = <WIDTH>
$$pin.leds=12
$$pin.uart_rx=1
$$pin.uart_tx=1
$$pin.P0A1=1 pin.P0A2=1 pin.P0A3=1 pin.P0A4=1
$$pin.P0A7=1 pin.P0A8=1 pin.P0A9=1 pin.P0A10=1
$$pin.P1A1=1 pin.P1A2=1 pin.P1A3=1 pin.P1A4=1
$$pin.P1A7=1 pin.P1A8=1 pin.P1A9=1 pin.P1A10=1
$$pin.P2A1=1 pin.P2A2=1 pin.P2A3=1 pin.P2A4=1
$$pin.P2A7=1 pin.P2A8=1 pin.P2A9=1 pin.P2A10=1
// pin groups and renaming
$$pin.video_r   = {pin.P0A4,pin.P0A3,pin.P0A2,pin.P0A1,0,0}
$$pin.video_g   = {pin.P1A4,pin.P1A3,pin.P1A2,pin.P1A1,0,0}
$$pin.video_b   = {pin.P0A10,pin.P0A9,pin.P0A8,pin.P0A7,0,0}
$$pin.video_hs  = {pin.P1A7}
$$pin.video_vs  = {pin.P1A8}
$$pin.ram_clk   = {pin.P2A4} pin.ram_csn   = {pin.P2A1}
$$pin.ram_io0   = {pin.P2A2} pin.ram_io1   = {pin.P2A3}
$$pin.ram_io2   = {pin.P2A7} pin.ram_io3   = {pin.P2A8}
$$pin.ram_bank  = {pin.P2A10,pin.P2A9}

module top(
  %TOP_SIGNATURE%
  input  clk100
  );

reg ready = 0;

reg [31:0] RST_d;
reg [31:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge clk100) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 32'b111111111111111111111111111111;
  end
end

wire run_main;
assign run_main = 1'b1;

wire design_clk;

%WIRE_DECL%

M_main __main(
  .clock    (clk100),
  .out_clock(design_clk),
  .reset    (RST_q[0]),
  %MAIN_GLUE%
  .in_run   (run_main)
);

endmodule
