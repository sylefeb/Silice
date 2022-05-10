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
`define ULX3S 1
`default_nettype none
$$ULX3S    = 1
$$HARDWARE = 1
$$NUM_LEDS = 8
$$NUM_BTNS = 7
$$color_depth = 6
$$color_max   = 63
$$config['dualport_bram_supported'] = 'yes'

module top(
  // basic
  output [7:0] leds,
  // buttons
  input  [6:0] btns,
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
`ifdef AUDIO
  // audio jack
  output [3:0] audio_l,
  output [3:0] audio_r,
`endif
`ifdef OLED
  // oled
  output  oled_clk,
  output  oled_mosi,
  output  oled_dc,
  output  oled_resn,
  output  oled_csn,
`endif
`ifdef SDCARD
  // sdcard
  output  sd_clk,
  output  sd_csn,
  output  sd_mosi,
  input   sd_miso,
  output  wifi_en,
`endif
`ifdef GPIO
  // gpio
  output [27:0] gp,
  input  [27:0] gn,
`endif
`ifdef VGA
  // vga
  output [27:0] gp,
  input  [27:0] gn,
`endif
`ifdef HDMI
  // hdmi
  output [3:0]  gpdi_dp, // {clock,R,G,B}
  // output [3:0]  gpdi_dn, // not used explicitely, using true differential with LVCMOS33D (see lpf file)
`endif
`ifdef US2_PS2
  // us2 connector for PS/2 peripheral
  input  usb_fpga_bd_dp,
  input  usb_fpga_bd_dn,
  output usb_fpga_pu_dp,
  output usb_fpga_pu_dn,
`endif
`ifdef UART
  // uart
  output  ftdi_rxd,
  input   ftdi_txd,
`endif
`ifdef UART2
  // uart2
`endif
`ifdef SPIFLASH
  output flash_csn,
  output flash_mosi,
  input  flash_miso,
`endif
  output wifi_gpio0,
  input  clk_25mhz
  );

wire [7:0]  __main_out_leds;

`ifdef OLED
wire        __main_oled_clk;
wire        __main_oled_mosi;
wire        __main_oled_dc;
wire        __main_oled_resn;
wire        __main_oled_csn;
`endif

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

`ifdef UART2
`ifndef GPIO
`error_UART2_needs_GPIO
`endif
`endif

`ifdef UART
wire        __main_out_uart_rx;
`endif

`ifdef VGA
wire        __main_out_vga_hs;
wire        __main_out_vga_vs;
wire [5:0]  __main_out_vga_r;
wire [5:0]  __main_out_vga_g;
wire [5:0]  __main_out_vga_b;
`endif

`ifdef SDCARD
wire        __main_sd_clk;
wire        __main_sd_csn;
wire        __main_sd_mosi;
`endif

`ifdef HDMI
wire [3:0]  __main_out_gpdi_dp;
`endif

`ifdef AUDIO
wire [3:0]  __main_out_audio_l;
wire [3:0]  __main_out_audio_r;
`endif

wire ready = btns[0];

reg [15:0] RST_d;
reg [15:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge clk_25mhz) begin
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
  .in_btns       (btns),
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
`ifdef AUDIO
  .out_audio_l  (__main_out_audio_l),
  .out_audio_r  (__main_out_audio_r),
`endif
`ifdef OLED
  .out_oled_clk (__main_oled_clk),
  .out_oled_mosi(__main_oled_mosi),
  .out_oled_dc  (__main_oled_dc),
  .out_oled_resn(__main_oled_resn),
  .out_oled_csn (__main_oled_csn),
`endif
`ifdef GPIO
`ifdef UART2
  .out_gp       (gp[27:1]),
  .in_gn        (gn[27:1]),
  .out_uart2_tx (gp[0]),
  .in_uart2_rx  (gn[0]),
`else
  .out_gp       (gp),
  .in_gn        (gn),
`endif
`endif
`ifdef UART
  .out_uart_tx  (__main_out_uart_rx),
  .in_uart_rx   (ftdi_txd),
`endif
`ifdef SPIFLASH
  .out_sf_clk(__main_flash_clk),
  .out_sf_csn(flash_csn),
  .out_sf_mosi(flash_mosi),
  .in_sf_miso(flash_miso),
`endif
`ifdef VGA
  .out_video_hs (__main_out_vga_hs),
  .out_video_vs (__main_out_vga_vs),
  .out_video_r  (__main_out_vga_r),
  .out_video_g  (__main_out_vga_g),
  .out_video_b  (__main_out_vga_b),
`endif
`ifdef HDMI
  .out_gpdi_dp  (__main_out_gpdi_dp),
`endif
  .clock         (clk_25mhz)
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

`ifdef AUDIO
assign audio_l       = __main_out_audio_l;
assign audio_r       = __main_out_audio_r;
`endif

`ifdef VGA
assign gp[0]         = __main_out_vga_vs;
assign gp[1]         = __main_out_vga_hs;
assign gp[2]         = __main_out_vga_r[5];
assign gp[3]         = __main_out_vga_r[4];
assign gp[4]         = __main_out_vga_r[3];
assign gp[5]         = __main_out_vga_r[2];
assign gp[6]         = __main_out_vga_r[1];
assign gp[7]         = __main_out_vga_r[0];
assign gp[8]         = __main_out_vga_g[5];
assign gp[9]         = __main_out_vga_g[4];
assign gp[10]        = __main_out_vga_g[3];
assign gp[11]        = __main_out_vga_g[2];
assign gp[12]        = __main_out_vga_g[1];
assign gp[13]        = __main_out_vga_g[0];
assign gp[14]        = __main_out_vga_b[0];
assign gp[15]        = __main_out_vga_b[1];
assign gp[16]        = __main_out_vga_b[2];
assign gp[17]        = __main_out_vga_b[3];
assign gp[18]        = __main_out_vga_b[4];
assign gp[19]        = __main_out_vga_b[5];
`endif

`ifdef SDCARD
assign sd_clk        = __main_sd_clk;
assign sd_csn        = __main_sd_csn;
assign sd_mosi       = __main_sd_mosi;
assign wifi_en       = 1'b0;
`endif

`ifdef OLED
assign oled_clk      = __main_oled_clk;
assign oled_mosi     = __main_oled_mosi;
assign oled_dc       = __main_oled_dc;
assign oled_resn     = __main_oled_resn;
assign oled_csn      = __main_oled_csn;
`endif

`ifdef UART
assign ftdi_rxd      = __main_out_uart_rx;
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

`ifdef US2_PS2
assign usb_fpga_pu_dp = 1;
assign usb_fpga_pu_dn = 1;
`endif

assign wifi_gpio0 = 1'b1; // see https://github.com/sylefeb/Silice/issues/207

endmodule
