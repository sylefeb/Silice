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

`define ICEPI_ZERO 1
`define ECP5  1
`default_nettype none
$$ICEPI_ZERO    = 1
$$ECP5     = 1
$$HARDWARE = 1
$$NUM_LEDS = 5
$$NUM_BTNS = 2
$$color_depth = 6
$$color_max   = 63
$$config['dualport_bram_supported'] = 'yes'

module top(
  // basic
  output [4:0] leds,
  // buttons
  input  [1:0] button,
`ifdef SDRAM
  // sdram
  output sdram_clk,
  output sdram_cke,
  output [1:0]  sdram_dqm,
  output sdram_csn,
  output sdram_wen,
  output sdram_casn,
  output sdram_rasn,
  output [1:0]  sdram_ba,
  output [12:0] sdram_a,
  inout  [15:0] sdram_dq,
`endif
`ifdef SDCARD
  // sdcard
  output  sd_clk,
  output  sd_csn,
  output  sd_mosi,
  input   sd_miso,
`endif
`ifdef GPIO
  // gpio
  inout [27:0] gpio,
`endif
`ifdef HDMI
  // hdmi
  output [3:0]  gpdi_dp, // {clock,R,G,B}
  // output [3:0]  gpdi_dn, // not used explicitely, using true differential with LVCMOS33D (see lpf file)
`endif
`ifdef US2_PS2
  // us2 connector for PS/2 peripheral
  input  [1:0] usb_dp,
  input  [1:0] usb_dn,
  output [1:0] usb_pull_dp,
  output [1:0] usb_pull_dn,
`endif
`ifdef UART
  // uart
  output  usb_tx,
  input   usb_rx,
`endif
`ifdef SPIFLASH
  output flash_csn,
  output flash_mosi,
  input  flash_miso,
`endif
`ifdef QSPIFLASH
  output flash_csn,
  inout  flash_mosi,
  inout  flash_miso,
  inout  flash_wpn,
  inout  flash_reset,
`endif
`ifdef I2C
  // i2c for rtc
  inout gpdi_sda,
  inout gpdi_scl,
`endif
  input  clk
  );

// Change 
reg clk25;
always @(posedge clk) begin
	clk25 = ~clk25;
end

wire [7:0]  __main_out_leds;

`ifdef SDRAM
wire        __main_out_sdram_clk;
wire        __main_out_sdram_cle;
wire [1:0]  __main_out_sdram_dqm;
wire        __main_out_sdram_cs;
wire        __main_out_sdram_we;
wire        __main_out_sdram_cas;
wire        __main_out_sdram_ras;
wire [1:0]  __main_out_sdram_ba;
wire [12:0] __main_out_sdram_a;
`endif

`ifdef UART
wire        __main_out_uart_tx;
`endif

`ifdef SDCARD
wire        __main_sd_clk;
wire        __main_sd_csn;
wire        __main_sd_mosi;
`endif

`ifdef HDMI
wire [3:0]  __main_out_gpdi_dp;
`endif

wire ready = button[0];

reg [15:0] RST_d;
reg [15:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge clk25) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    RST_q <= 16'b111111111111111;
  end
end

wire run_main;
assign run_main = 1'b1;

M_main __main(
  .reset         (RST_q[0]),
  .in_run        (run_main),
  .out_leds      (__main_out_leds),
`ifdef BUTTONS
  .in_btns       (button),
`endif
`ifdef SDRAM
  .inout_sdram_dq(sdram_dq),
  .out_sdram_clk (__main_out_sdram_clk),
  .out_sdram_cle (__main_out_sdram_cle),
  .out_sdram_dqm (__main_out_sdram_dqm),
  .out_sdram_cs  (__main_out_sdram_cs),
  .out_sdram_we  (__main_out_sdram_we),
  .out_sdram_cas (__main_out_sdram_cas),
  .out_sdram_ras (__main_out_sdram_ras),
  .out_sdram_ba  (__main_out_sdram_ba),
  .out_sdram_a   (__main_out_sdram_a),
`endif
`ifdef US2_PS2
  .in_us2_bd_dp(usb_fpga_bd_dp),
  .in_us2_bd_dn(usb_fpga_bd_dn),
`endif
`ifdef SDCARD
  .out_sd_csn    (__main_sd_csn),
  .out_sd_clk    (__main_sd_clk),
  .out_sd_mosi   (__main_sd_mosi),
  .in_sd_miso    (sd_miso),
`endif
`ifdef GPIO
  .inout_gpio          (gpio),
`endif
`ifdef UART
  .out_uart_tx  (__main_out_uart_tx),
  .in_uart_rx   (usb_rx),
`endif
`ifdef SPIFLASH
  .out_sf_clk(__main_flash_clk),
  .out_sf_csn(flash_csn),
  .out_sf_mosi(flash_mosi),
  .in_sf_miso(flash_miso),
`endif
`ifdef QSPIFLASH
  .out_sf_clk(__main_flash_clk),
  .out_sf_csn(flash_csn),
  .inout_sf_io0(flash_mosi),
  .inout_sf_io1(flash_miso),
  .inout_sf_io2(flash_wpn),
  .inout_sf_io3(flash_reset),
`endif
`ifdef HDMI
  .out_gpdi_dp  (__main_out_gpdi_dp),
`endif
`ifdef I2C
  .inout_gpdi_sda(gpdi_sda),
  .inout_gpdi_scl(gpdi_scl),
`endif
`ifdef PMOD_QQSPI
  // NOTE: overlaps with gp/gn (14 to 17)
  .inout_ram_io0(qqspi_io0),
  .inout_ram_io1(qqspi_io1),
  .inout_ram_io2(qqspi_io2),
  .inout_ram_io3(qqspi_io3),
  .out_ram_clk(qqspi_clk),
  .out_ram_csn(qqspi_csn),
  .out_ram_bank({qqspi_bank1,qqspi_bank0}),
`endif
  .clock         (clk25)
);

assign leds          = __main_out_leds;

`ifdef SDRAM
assign sdram_clk     = __main_out_sdram_clk;
assign sdram_cke     = __main_out_sdram_cle;
assign sdram_dqm     = __main_out_sdram_dqm;
assign sdram_csn     = __main_out_sdram_cs;
assign sdram_wen     = __main_out_sdram_we;
assign sdram_casn    = __main_out_sdram_cas;
assign sdram_rasn    = __main_out_sdram_ras;
assign sdram_ba      = __main_out_sdram_ba;
assign sdram_a       = __main_out_sdram_a;
`endif

`ifdef SDCARD
assign sd_clk        = __main_sd_clk;
assign sd_csn        = __main_sd_csn;
assign sd_mosi       = __main_sd_mosi;
`endif

`ifdef UART
assign usb_tx        = __main_out_uart_tx;
`endif

`ifdef HDMI
assign gpdi_dp       = __main_out_gpdi_dp;
`endif

`ifdef SPIFLASH
wire __main_flash_clk;
USRMCLK usrmclk_flash(
          .USRMCLKI(__main_flash_clk),
          .USRMCLKTS(1'b0));
`endif

`ifdef QSPIFLASH
wire __main_flash_clk;
USRMCLK usrmclk_flash(
          .USRMCLKI(__main_flash_clk),
          .USRMCLKTS(1'b0));
`endif

`ifdef US2_PS2
assign usb_pull_dp[0] = 1;
assign usb_pull_dn[0] = 1;
`endif

endmodule
