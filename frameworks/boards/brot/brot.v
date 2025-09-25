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
`ifdef BASIC
  output LED_R,
  output LED_G,
  output LED_B,
`endif
`ifdef BUTTONS
`error_this_board_has_no_buttons
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
  output SPI_SS_RAM,  // unselect psram as lines are shared (disallowed together)
`endif
`ifdef SPIFLASH_DSPI
  output SPI_SCK,
  output SPI_SS_FLASH,
  inout  SPI_MOSI,
  inout  SPI_MISO,
  output SPI_SS_RAM,  // unselect psram as lines are shared (disallowed together)
`endif
`ifdef PMOD_DSPI
  output PMOD_A7,
  inout  PMOD_A8,
  inout  PMOD_A9,
  output PMOD_A10,
`endif
`ifdef QPSRAM
  output SPI_SCK,
  output SPI_SS_RAM,
  inout  SPI_MOSI,
  inout  SPI_MISO,
  inout  SPI_IO2,
  inout  SPI_IO3,
  output SPI_SS_FLASH, // unselect spiflash as lines are shared (disallowed together)
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
`ifdef SERIAL_IN
  input PMOD_A2,
`endif
`ifdef UART
  output PMOD_B7,  // TX
  input  PMOD_B10, // RX
`endif
`ifdef UART_RX_ONLY
  input  PMOD_B10, // RX
`endif
`ifdef UART2
  input  GPIO0,  // TX
  output GPIO1, // RX
`endif
`ifdef PS2
  input  GPIO2, // clock
  input  GPIO3, // data
`endif
`ifdef SDCARD
  output GPIO4, // cs
  output GPIO5, // clock
  output GPIO6, // mosi
  input  GPIO7, // miso
`endif
`ifdef PMOD_COM_OUT
  output PMOD_B1,
  output PMOD_B2,
  output PMOD_B3,
  output PMOD_B4,
  output PMOD_B7,
  output PMOD_B8,
  output PMOD_B9,
  output PMOD_B10,
  output PMOD_A3,
  output PMOD_A4,
`endif
`ifdef PMOD_COM_IN
  input PMOD_A1,
  input PMOD_A2,
  input PMOD_A3,
  input PMOD_A4,
  input PMOD_A7,
  input PMOD_A8,
  input PMOD_A9,
  input PMOD_A10,
  input PMOD_B3,
  input PMOD_B4,
`endif
`ifdef SYNC_IN
  input PMOD_A1,
`endif
`ifdef SYNC_OUT
  output PMOD_B9,
`endif
`ifdef VGA
  output GPIO0,   // R0
  output GPIO1,   // R1
  output GPIO2,   // R2
  output PMOD_B1, // G0
  output GPIO3,   // G1
  output GPIO4,   // G2
  output GPIO5,   // G3
  output PMOD_B2, // B0
  output PMOD_B8, // B1
  output GPIO6,   // B2
  output GPIO7,   // HS
  output PMOD_B7, // VS
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

`ifdef QPSRAM
wire [1:0] psram_unused;
assign SPI_SS_FLASH = 1'b1;
`ifdef SPIFLASH
`error_cannot_use_spiflash_and_qpsram_together
`endif
`ifdef SPIFLASH_DSPI
`error_cannot_use_spiflash_and_qpsram_together
`endif
`endif

`ifdef SPIFLASH
assign SPI_SS_RAM = 1'b1;
`ifdef QPSRAM
`error_cannot_use_spiflash_and_qpsram_together
`endif
`endif

`ifdef SPIFLASH_DSPI
assign SPI_SS_RAM = 1'b1;
`ifdef QPSRAM
`error_cannot_use_spiflash_and_qpsram_together
`endif
`endif

`ifdef BASIC
wire lr;
wire lg;
wire lb;
assign LED_R = ~lr;
assign LED_G = ~lg;
assign LED_B = ~lb;
`endif

`ifdef PARALLEL_SCREEN
wire prlscreen_unused;
`endif

M_main __main(
  .clock(CLK_48),
  .out_clock(design_clk),
  .reset(~RST_q[15]),
`ifdef BASIC
  .out_leds({lb,lg,lr}),
`endif
`ifdef BUTTONS
`endif
`ifdef PMOD
  .inout_pmod({PMOD_A10,PMOD_A9,PMOD_A8,PMOD_A7,PMOD_A4,PMOD_A3,PMOD_A2,PMOD_A1}),
`endif
`ifdef SPIFLASH
  .out_sf_csn (SPI_SS_FLASH),
  .out_sf_clk (SPI_SCK),
  .out_sf_mosi(SPI_MOSI),
  .in_sf_miso (SPI_MISO),
`endif
`ifdef SPIFLASH_DSPI
  .out_sf_csn  (SPI_SS_FLASH),
  .out_sf_clk  (SPI_SCK),
  .inout_sf_io0(SPI_MOSI),
  .inout_sf_io1(SPI_MISO),
`endif
`ifdef PMOD_DSPI
  .out_sf_csn(PMOD_A7),
  .inout_sf_io0(PMOD_A8),
  .inout_sf_io1(PMOD_A9),
  .out_sf_clk(PMOD_A10),
`endif
`ifdef QPSRAM
  .out_ram_csn  (SPI_SS_RAM),
  .inout_ram_io0(SPI_MOSI),
  .inout_ram_io1(SPI_MISO),
  .inout_ram_io2(SPI_IO2),
  .inout_ram_io3(SPI_IO3),
  .out_ram_clk  (SPI_SCK),
  .out_ram_bank (psram_unused),
`endif
`ifdef PARALLEL_SCREEN
  .out_prlscreen_d({GPIO7,GPIO6,GPIO5,GPIO4,GPIO3,GPIO2,GPIO1,GPIO0}),
  .out_prlscreen_resn(PMOD_B1),
  .out_prlscreen_csn (PMOD_B7),
  .out_prlscreen_rs  (PMOD_B8),
  .out_prlscreen_clk (PMOD_B2),
`endif
`ifdef SERIAL_IN
  .in_serial_in(PMOD_A2),
`endif
`ifdef UART
  .out_uart_tx(PMOD_B7),
  .in_uart_rx (PMOD_B10),
`endif
`ifdef UART_RX_ONLY
  .in_uart_rx (PMOD_B10),
`endif
`ifdef UART2
  .out_uart_tx(GPIO1),
  .in_uart_rx (GPIO0),
`endif
`ifdef PS2
  .in_ps2_clock(GPIO2),
  .in_ps2_data(GPIO3),
`endif
`ifdef SDCARD
  .out_sd_csn  (GPIO4),
  .out_sd_clk  (GPIO5),
  .out_sd_mosi (GPIO6),
  .in_sd_miso  (GPIO7),
`endif
`ifdef SYNC_IN
  .in_sync(PMOD_A1),
`endif
`ifdef SYNC_OUT
  .out_sync(PMOD_B9),
`endif
/*
PMOD com wiring:
out fpga     in fpga
PMOD_B10 (48) <-> PMOD_A1 (47)
PMOD_B9  (3)  <-> PMOD_A2 (45)
PMOD_B8  (6)  <-> PMOD_A3 (43)
PMOD_B7  (10) <-> PMOD_A4 (38)
PMOD_B4  (2)  <-> PMOD_A7 (46)
PMOD_B3  (4)  <-> PMOD_A8 (44)
PMOD_B2  (9)  <-> PMOD_A9 (42)
PMOD_A3  (43) <-> PMOD_B4 (2)
PMOD_A4  (38) <-> PMOD_B3 (4)

PMOD_A8 is on a global buffer on the 'in fpga' and has to be used for the clock
*/
`ifdef PMOD_COM_OUT
  .out_com_data({PMOD_B10,PMOD_B9,PMOD_B8,PMOD_B7,PMOD_B4,PMOD_A3,PMOD_B2,PMOD_B1}),
  .out_com_clock(PMOD_B3),
  .out_com_valid(PMOD_A4),
`endif
`ifdef PMOD_COM_IN
  .in_com_data({PMOD_A1,PMOD_A2,PMOD_A3,PMOD_A4,PMOD_A7,PMOD_B4,PMOD_A9,PMOD_A10}),
  .in_com_clock(PMOD_A8),
  .in_com_valid(PMOD_B3),
`endif
`ifdef VGA
  .out_video_r({GPIO0,GPIO1,GPIO2}),
  .out_video_g({PMOD_B1,GPIO3,GPIO4,GPIO5}),
  .out_video_b({GPIO6,PMOD_B8,PMOD_B2}),
  .out_video_hs(GPIO7),
  .out_video_vs(PMOD_B7),
`endif
// -----------------------------------------------------------------------------
  .in_run(run_main)
);
// -----------------------------------------------------------------------------

endmodule
