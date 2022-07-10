/*

Copyright 2019, (C) Gwenhael Goavec-Mero, Sylvain Lefebvre and contributors
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
`define RIEGEL 1
`define ICE40 1
`default_nettype none
$$RIEGEL=1
$$ICE40=1
$$HARDWARE=1
$$NUM_LEDS=1
$$NUM_BTNS=0
$$color_depth=1
$$color_max  =1
$$config['bram_wenable_width'] = '1'
$$config['dualport_bram_wenable0_width'] = 'data'
$$config['dualport_bram_wenable1_width'] = 'data'
$$config['simple_dualport_bram_wenable0_width'] = 'data'
$$config['simple_dualport_bram_wenable1_width'] = 'data'

module top(
  output LED_A,
`ifdef VGA
  output VGA_R, // r0
  output VGA_G,   // b0
  output VGA_B,  // g0
  output VGA_HS,  // hs
  output VGA_VS,  // vs
`endif
`ifdef PMOD
  inout PMOD_A1,
  inout PMOD_A2,
  inout PMOD_A3,
  inout PMOD_A4,
  inout PMOD_A7,
  inout PMOD_A8,
  inout PMOD_A9,
  inout PMOD_A10,
`endif
`ifdef SPIFLASH
  output SPI_SCK,
  output SPI_SS_FLASH,
  output SPI_MOSI,
  input  SPI_MISO,
`endif
  input  CLK_48
  );

// clock from design is used in case
// it relies on a PLL: in such cases
// we cannot use the clock fed into
// the PLL here
wire design_clk;

reg ready = 0;
reg [23:0] RST_d;
reg [23:0] RST_q;

always @* begin
  RST_d = RST_q[23] ? RST_q : RST_q + 1;
end

always @(posedge design_clk) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 0;
  end
end

wire run_main;
assign run_main = 1'b1;

M_main __main(
  .clock(CLK_48),
  .out_clock(design_clk),
  .reset(~RST_q[23]),
  .out_leds(LED_A),
`ifdef VGA
  .out_video_hs(VGA_HS),
  .out_video_vs(VGA_VS),
  .out_video_r(VGA_R),
  .out_video_g(VGA_G),
  .out_video_b(VGA_B),
`endif
`ifdef PMOD
  .inout_pmod({PMOD_A10,PMOD_A9,PMOD_A8,PMOD_A7,PMOD_A4,PMOD_A3,PMOD_A2,PMOD_A1}),
`endif
`ifdef SPIFLASH
  .out_sf_clk(SPI_SCK),
  .out_sf_csn(SPI_SS_FLASH),
  .out_sf_mosi(SPI_MOSI),
  .in_sf_miso(SPI_MISO),
`endif
  .in_run(run_main)
);

endmodule
