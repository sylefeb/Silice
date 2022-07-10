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
`define ICEBITSY 1
`define ICE40 1
`default_nettype none
$$ICEBITSY=1
$$ICE40=1
$$HARDWARE=1
$$NUM_LEDS=5
$$NUM_BTNS=1
$$color_depth=6
$$color_max  =63
$$config['bram_wenable_width'] = '1'
$$config['dualport_bram_wenable0_width'] = 'data'
$$config['dualport_bram_wenable1_width'] = 'data'
$$config['simple_dualport_bram_wenable0_width'] = 'data'
$$config['simple_dualport_bram_wenable1_width'] = 'data'

module top(
  output LEDR_N,
  output LEDG_N,
  output LED_RED_N,
  output LED_GRN_N,
  output LED_BLU_N,
`ifdef BUTTONS
  input BTN_N,
`endif
`ifdef UART
  output TX,
  input  RX,
`endif
`ifdef VGA
  output P1_1, // r0
  output P1_2, // r1
  output P1_3, // r2
  output P1_4, // r3

  output P1_7,   // b0
  output P1_8,   // b1
  output P1_9,   // b2
  output P1_10,  // b3

  output P2_1,  // g0
  output P2_2,  // g1
  output P2_3,  // g2
  output P2_4,  // g3

  output P2_7,  // hs
  output P2_8,  // vs
`endif
`ifdef PMOD
  inout P1_1,
  inout P1_2,
  inout P1_3,
  inout P1_4,
  inout P1_7,
  inout P1_8,
  inout P1_9,
  inout P1_10,
`endif
`ifdef SPIFLASH
  output FLASH_SCK,
  output FLASH_CS,
  output FLASH_IO0,
  input  FLASH_IO1,
  output FLASH_IO2,
  output FLASH_IO3,
`endif
`ifdef QSPIFLASH
  output FLASH_SCK,
  output FLASH_CS,
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
wire [5:0] __main_out_vga_r;
wire [5:0] __main_out_vga_g;
wire [5:0] __main_out_vga_b;
`ifdef PMOD
`error_cannot_use_both_VGA_and_PMOD_same_pins
`endif
`endif

reg ready = 0;
reg [31:0] RST_d;
reg [31:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge design_clk) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 32'b111111111111111111111111111111;
  end
end

wire run_main;
assign run_main = 1'b1;

M_main __main(
  .clock(CLK),
  .out_clock(design_clk),
  .reset(RST_q[0]),
  .out_leds(__main_leds),
`ifdef BUTTONS
  .in_btns({BTN3,BTN2,BTN1}),
`endif
`ifdef UART
  .out_uart_tx(TX),
  .in_uart_rx(RX),
`endif
`ifdef VGA
  .out_video_hs(P2_7),
  .out_video_vs(P2_8),
  .out_video_r(__main_out_vga_r),
  .out_video_g(__main_out_vga_g),
  .out_video_b(__main_out_vga_b),
`endif
`ifdef PMOD
  .inout_pmod({P1_10,P1_9,P1_8,P1_7,P1_4,P1_3,P1_2,P1_1}),
`endif
`ifdef SPIFLASH
  .out_sf_clk(FLASH_SCK),
  .out_sf_csn(FLASH_CS),
  .out_sf_mosi(FLASH_IO0),
  .in_sf_miso(FLASH_IO1),
`endif
`ifdef QSPIFLASH
  .out_sf_clk(FLASH_SCK),
  .out_sf_csn(FLASH_CS),
  .inout_sf_io0(FLASH_IO0),
  .inout_sf_io1(FLASH_IO1),
  .inout_sf_io2(FLASH_IO2),
  .inout_sf_io3(FLASH_IO3),
`endif
  .in_run(run_main)
);

assign LEDR_N    = ~__main_leds[0+:1];
assign LEDG_N    = ~__main_leds[1+:1];
assign LED_RED_N = ~__main_leds[2+:1];
assign LED_GRN_N = ~__main_leds[3+:1];
assign LED_BLU_N = ~__main_leds[4+:1];


`ifdef VGA
assign P1_1  = __main_out_vga_r[2+:1];
assign P1_2  = __main_out_vga_r[3+:1];
assign P1_3  = __main_out_vga_r[4+:1];
assign P1_4  = __main_out_vga_r[5+:1];

assign P1_7  = __main_out_vga_b[2+:1];
assign P1_8  = __main_out_vga_b[3+:1];
assign P1_9  = __main_out_vga_b[4+:1];
assign P1_10 = __main_out_vga_b[5+:1];

assign P2_1  = __main_out_vga_g[2+:1];
assign P2_2  = __main_out_vga_g[3+:1];
assign P2_3  = __main_out_vga_g[4+:1];
assign P2_4  = __main_out_vga_g[5+:1];
`endif

endmodule
