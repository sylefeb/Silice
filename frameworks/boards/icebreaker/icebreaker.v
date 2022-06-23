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
`define ICEBREAKER 1
`define ICE40 1
`default_nettype none
$$ICEBREAKER=1
$$ICE40=1
$$HARDWARE=1
$$NUM_LEDS=5
$$NUM_BTNS=3
$$color_depth=6
$$color_max  =63
$$config['bram_wenable_width'] = '1'
$$config['dualport_bram_wenable0_width'] = '1'
$$config['dualport_bram_wenable1_width'] = '1'
$$config['simple_dualport_bram_wenable0_width'] = '1'
$$config['simple_dualport_bram_wenable1_width'] = '1'

module top(
  output LED1,
  output LED2,
  output LED3,
  output LED4,
  output LED5,
`ifdef BUTTONS
  input BTN1,
  input BTN2,
  input BTN3,
`endif
`ifdef UART
  output TX,
  input  RX,
`endif
`ifdef VGA
  output P1A1, // r0
  output P1A2, // r1
  output P1A3, // r2
  output P1A4, // r3

  output P1A7,   // b0
  output P1A8,   // b1
  output P1A9,   // b2
  output P1A10,  // b3

  output P1B1,  // g0
  output P1B2,  // g1
  output P1B3,  // g2
  output P1B4,  // g3

  output P1B7, // hs
  output P1B8,  // vs
`endif
`ifdef OLED
  output P1A1,
  output P1A2,
  output P1A3,
  output P1A4,
`endif
`ifdef PMOD
  inout P1A1,
  inout P1A2,
  inout P1A3,
  inout P1A4,
  inout P1A7,
  inout P1A8,
  inout P1A9,
  inout P1A10,
`endif
`ifdef SPIFLASH
  output FLASH_SCK,
  output FLASH_SSB,
  output FLASH_IO0,
  input  FLASH_IO1,
  output FLASH_IO2,
  output FLASH_IO3,
`endif
`ifdef QSPIFLASH
  output FLASH_SCK,
  output FLASH_SSB,
  inout  FLASH_IO0,
  inout  FLASH_IO1,
  inout  FLASH_IO2,
  inout  FLASH_IO3,
`endif
  input  CLK
  );

wire [4:0] __main_leds;

// clock from design is used in case
// it relies on a PLL: in such cases
// we cannot use the clock fed into
// the PLL here
wire design_clk;

`ifdef VGA
wire __main_out_vga_hs;
wire __main_out_vga_vs;
wire [5:0] __main_out_vga_r;
wire [5:0] __main_out_vga_g;
wire [5:0] __main_out_vga_b;
`ifdef PMOD
`error_cannot_use_both_VGA_and_PMOD_same_pins
`endif
`endif

`ifdef OLED
wire __main_oled_clk;
wire __main_oled_mosi;
wire __main_oled_csn;
wire __main_oled_resn;
wire __main_oled_dc;
`ifdef VGA
`error_cannot_use_both_OLED_and_VGA_same_pins
`endif
`ifdef PMOD
`error_cannot_use_both_OLED_and_PMOD_same_pins
`endif
`endif

`ifdef SPIFLASH
wire __main_out_sf_clk;
wire __main_out_sf_csn;
wire __main_out_sf_mosi;
`endif

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
  .clock(CLK),
  .out_clock(design_clk),
  .reset(~RST_q[23]),
  .out_leds(__main_leds),
`ifdef BUTTONS
  .in_btns({BTN3,BTN2,BTN1}),
`endif
`ifdef UART
  .out_uart_tx(TX),
  .in_uart_rx(RX),
`endif
`ifdef VGA
  .out_video_hs(__main_out_vga_hs),
  .out_video_vs(__main_out_vga_vs),
  .out_video_r(__main_out_vga_r),
  .out_video_g(__main_out_vga_g),
  .out_video_b(__main_out_vga_b),
`endif
`ifdef PMOD
  .inout_pmod({P1A10,P1A9,P1A8,P1A7,P1A4,P1A3,P1A2,P1A1}),
`endif
`ifdef OLED
  .out_oled_mosi(__main_oled_mosi),
  .out_oled_clk(__main_oled_clk),
  .out_oled_csn(__main_oled_csn),
  .out_oled_dc(__main_oled_dc),
  .out_oled_resn(__main_oled_resn),
`endif
`ifdef SPIFLASH
  .out_sf_clk(__main_out_sf_clk),
  .out_sf_csn(__main_out_sf_csn),
  .out_sf_mosi(__main_out_sf_mosi),
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
  .in_run(run_main)
);

assign LED4 = __main_leds[0+:1];
assign LED3 = __main_leds[1+:1];
assign LED5 = __main_leds[2+:1];
assign LED2 = __main_leds[3+:1];
assign LED1 = __main_leds[4+:1];

`ifdef VGA
assign P1A1  = __main_out_vga_r[2+:1];
assign P1A2  = __main_out_vga_r[3+:1];
assign P1A3  = __main_out_vga_r[4+:1];
assign P1A4  = __main_out_vga_r[5+:1];

assign P1A7  = __main_out_vga_b[2+:1];
assign P1A8  = __main_out_vga_b[3+:1];
assign P1A9  = __main_out_vga_b[4+:1];
assign P1A10 = __main_out_vga_b[5+:1];

assign P1B1  = __main_out_vga_g[2+:1];
assign P1B2  = __main_out_vga_g[3+:1];
assign P1B3  = __main_out_vga_g[4+:1];
assign P1B4  = __main_out_vga_g[5+:1];

assign P1B7  = __main_out_vga_hs;
assign P1B8  = __main_out_vga_vs;
`endif

`ifdef OLED
assign P1A1  = __main_oled_resn;
assign P1A2  = __main_oled_dc;
assign P1A3  = __main_oled_clk;
assign P1A4  = __main_oled_mosi;
`endif

`ifdef SPIFLASH
assign FLASH_SCK = __main_out_sf_clk;
assign FLASH_SSB = __main_out_sf_csn;
assign FLASH_IO0 = __main_out_sf_mosi;
assign FLASH_IO2 = 1;
assign FLASH_IO3 = 1;
`endif

endmodule
