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

// for tinytapeout we target ice40, but then replace SB_IO cells
// by a custom implementation
`define ICE40 1
$$ICE40=1
`define SIM_SB_IO 1
$$SIM_SB_IO=1

`default_nettype none
$$HARDWARE = 1
$$NUM_LEDS = 12
$$color_depth=6
$$color_max  =63
// config
$$config['dualport_bram_supported'] = 'yes'
// declare package pins (has to match the hardware pin definition)
// pin.NAME = <WIDTH>
$$pin.gp         = 28
$$pin.gn         = 28
$$pin.leds       = 8
$$pin.video_r    = {pin.gp[2],pin.gp[3],pin.gp[4],pin.gp[5],pin.gp[6],pin.gp[7]}
$$pin.video_g    = {pin.gp[8],pin.gp[9],pin.gp[10],pin.gp[11],pin.gp[12],pin.gp[13]}
$$pin.video_b    = {pin.gp[14],pin.gp[15],pin.gp[16],pin.gp[17],pin.gp[18],pin.gp[19]}
$$pin.video_hs   = {pin.gp[1]}
$$pin.video_vs   = {pin.gp[0]}
$$pin.btns       = 7
$$pin.sdram_clk  = 1
$$pin.sdram_cke  = 1
$$pin.sdram_dqm  = 2
$$pin.sdram_csn  = 1
$$pin.sdram_wen  = 1
$$pin.sdram_casn = 1
$$pin.sdram_rasn = 1
$$pin.sdram_ba   = 2
$$pin.sdram_a    = 13
$$pin.sdram_dq   = 16
$$pin.audio_l    = 4
$$pin.audio_r    = 4
$$pin.oled_clk   = 1
$$pin.oled_mosi  = 1
$$pin.oled_dc    = 1
$$pin.oled_resn  = 1
$$pin.oled_csn   = 1
$$pin.sd_clk     = 1
$$pin.sd_csn     = 1
$$pin.sd_mosi    = 1
$$pin.sd_miso    = 1
$$pin.wifi_en    = 1
$$pin.gpdi_dp    = 4
$$pin.usb_fpga_bd_dp = 1
$$pin.usb_fpga_bd_dn = 1
$$pin.usb_fpga_pu_dp = 1
$$pin.usb_fpga_pu_dn = 1
$$pin.ftdi_rxd   = 1
$$pin.ftdi_txd   = 1
$$pin.uart_rx    = 1
$$pin.uart_tx    = 1
$$pin.flash_csn  = 1
$$pin.flash_mosi = 1
$$pin.flash_miso = 1
$$pin.flash_wpn  = 1
$$pin.flash_holdn= 1
$$pin.gpdi_sda   = 1
$$pin.gpdi_scl   = 1
$$pin.qqspi_io0  = 1
$$pin.qqspi_io1  = 1
$$pin.qqspi_io2  = 1
$$pin.qqspi_io3  = 1
$$pin.qqspi_clk  = 1
$$pin.qqspi_csn  = 1
$$pin.qqspi_bank0= 1
$$pin.qqspi_bank1= 1

module top(
  %TOP_SIGNATURE%
  output wifi_gpio0,
  input  clk_25mhz
  );

reg ready = 0;

reg [31:0] RST_d;
reg [31:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge clk_25mhz) begin
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
  .clock    (clk_25mhz),
  .out_clock(design_clk),
  .reset    (RST_q[0]),
  %MAIN_GLUE%
  .in_run   (run_main)
);

assign wifi_gpio0 = 1'b1; // see https://github.com/sylefeb/Silice/issues/207

endmodule
