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
`define BROT 1
`define ICE40 1
`default_nettype none
$$BROT=1
$$ICE40=1
$$HARDWARE=1
$$NUM_LEDS=3
$$NUM_BTNS=0
$$color_depth=6
$$color_max  =63
$$config['bram_wenable_width'] = '1'
$$config['dualport_bram_wenable0_width'] = '1'
$$config['dualport_bram_wenable1_width'] = '1'
$$config['simple_dualport_bram_wenable0_width'] = '1'
$$config['simple_dualport_bram_wenable1_width'] = '1'

module top(
  output LED_R,
  output LED_G,
  output LED_B,
`ifdef BUTTONS
`error_this_board_has_no_buttons
`endif
`ifdef UART
`error_this_board_has_no_uart
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
`ifdef PMOD2
  inout PMOD_B1,
  inout PMOD_B2,
  inout PMOD_B3,
  inout PMOD_B4,
  inout PMOD_B7,
  inout PMOD_B8,
  inout PMOD_B9,
  inout PMOD_B10,
`endif
`ifdef SPIFLASH
  output SPI_SCK,
  output SPI_SS_FLASH,
  output SPI_MOSI,
  input  SPI_MISO,
  output SPI_IO2,
  output SPI_IO3,
`endif
`ifdef PMOD_QQSPI
  output PMOD_A1,
  inout  PMOD_A2,
  inout  PMOD_A3,
  output PMOD_A4,
  inout  PMOD_A7,
  inout  PMOD_A8,
  output PMOD_A9,
  output PMOD_A10,
`endif
`ifdef PARALLEL_SCREEN
  output GPIO0,
  output GPIO1,
  output GPIO2,
  output GPIO3,
  output GPIO4,
  output GPIO5,
  output GPIO6,
  output GPIO7,
  output PMOD_B1,
  output PMOD_B2,
  output PMOD_B7,
  output PMOD_B8,
`endif
  input  CLK_48
  );

// clock from design is used in case
// it relies on a PLL: in such cases
// we cannot use the clock fed into
// the PLL here
wire design_clk;

`ifdef SPIFLASH
wire __main_out_sf_clk;
wire __main_out_sf_csn;
wire __main_out_sf_mosi;
`endif

reg ready = 0;
reg [15:0] RST_d;
reg [15:0] RST_q;

always @* begin
  RST_d = RST_q[15] ? RST_q : RST_q + 1;
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
  .reset(~RST_q[15]),
  .out_leds({LED_B,LED_G,LED_R}),
`ifdef BUTTONS
`endif
`ifdef PMOD
  .inout_pmod({PMOD_A10,PMOD_A9,PMOD_A8,PMOD_A7,PMOD_A4,PMOD_A3,PMOD_A2,PMOD_A1}),
`endif
`ifdef SPIFLASH
  .out_sf_clk(FLASH_SCK),
  .out_sf_csn(FLASH_SSB),
  .out_sf_mosi(FLASH_IO0),
  .in_sf_miso(FLASH_IO1),
`endif
`ifdef QSPIFLASH
  .out_sf_clk(FLASH_SCK),
  .out_sf_csn(FLASH_SSB),
  .inout_sf_io0(FLASH_IO0),
  .inout_sf_io1(FLASH_IO1),
  .inout_sf_io2(FLASH_IO2),
  .inout_sf_io3(FLASH_IO3),
`endif
`ifdef PMOD_QQSPI
  .inout_ram_io0(PMOD_A2),
  .inout_ram_io1(PMOD_A3),
  .inout_ram_io2(PMOD_A7),
  .inout_ram_io3(PMOD_A8),
  .out_ram_clk(PMOD_A4),
  .out_ram_csn(PMOD_A1),
  .out_ram_bank({PMOD_A10,PMOD_A9}),
`endif
`ifdef PARALLEL_SCREEN
  .out_prlscreen_d({GPIO6,GPIO7,GPIO4,GPIO5,GPIO2,GPIO3,GPIO0,GPIO1}),
  .out_prlscreen_resn(PMOD_B1),
  .out_prlscreen_csn(PMOD_B7),
  .out_prlscreen_rs(PMOD_B2),
  .out_prlscreen_clk(PMOD_B8),
`endif
  .in_run(run_main)
);

endmodule
