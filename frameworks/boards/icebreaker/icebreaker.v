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
$$ICEBREAKER  = 1
$$ICE40       = 1
$$HARDWARE    = 1
$$color_depth = 6
$$color_max   = 63
// config
$$config['bram_wenable_width'] = '1'
$$config['dualport_bram_wenable0_width'] = '1'
$$config['dualport_bram_wenable1_width'] = '1'
$$config['simple_dualport_bram_wenable0_width'] = '1'
$$config['simple_dualport_bram_wenable1_width'] = '1'
$$config['allow_deprecated_framework'] = 'no'
// declare package pins (has to match the hardware pin definition)
// pin.NAME = <WIDTH>
$$pin.LED1=1 pin.LED2=1 pin.LED3=1 pin.LED4=1 pin.LED5=1
$$pin.BTN1=1 pin.BTN2=1 pin.BTN3=1
$$pin.TX=1   pin.RX=1
$$pin.P1A1=1 pin.P1A2=1 pin.P1A3=1 pin.P1A4=1
$$pin.P1A7=1 pin.P1A8=1 pin.P1A9=1 pin.P1A10=1
$$pin.P1B1=1 pin.P1B2=1 pin.P1B3=1 pin.P1B4=1
$$pin.P1B7=1 pin.P1B8=1 pin.P1B9=1 pin.P1B10=1
$$pin.P2_1=1 pin.P2_2=1 pin.P2_3=1 pin.P2_4=1
$$pin.P2_7=1 pin.P2_8=1 pin.P2_9=1 pin.P2_10=1
$$pin.FLASH_SCK=1 pin.FLASH_SSB=1 pin.FLASH_IO0=1 pin.FLASH_IO1=1
$$pin.FLASH_IO2=1 pin.FLASH_IO3=1
$$pin.RGB_R=1 pin.RGB_G=1 pin.RGB_B=1
// pin groups and renaming
$$pin.leds      = {pin.LED1,pin.LED2,pin.LED5,pin.LED3,pin.LED4}
$$pin.btns      = {pin.BTN3,pin.BTN2,pin.BTN1}
$$pin.uart_tx   = {pin.TX}
$$pin.uart_rx   = {pin.RX}
$$pin.video_r   = {pin.P1A4 ,pin.P1A3,pin.P1A2,pin.P1A1,0,0}
$$pin.video_g   = {pin.P1B4 ,pin.P1B3,pin.P1B2,pin.P1B1,0,0}
$$pin.video_b   = {pin.P1A10,pin.P1A9,pin.P1A8,pin.P1A7,0,0}
$$pin.video_hs  = {pin.P1B7}
$$pin.video_vs  = {pin.P1B8}
$$pin.pmod      = {pin.P1A10,pin.P1A9,pin.P1A8,pin.P1A7,pin.P1A4,pin.P1A3,pin.P1A2,pin.P1A1}
$$pin.pmod2     = {pin.P1B10,pin.P1B9,pin.P1B8,pin.P1B7,pin.P1B4,pin.P1B3,pin.P1B2,pin.P1B1}
$$pin.oled_mosi = {pin.P1A4} pin.oled_clk  = {pin.P1A3}
$$pin.oled_dc   = {pin.P1A2} pin.oled_resn = {pin.P1A1}
$$pin.sf_clk    = {pin.FLASH_SCK} pin.sf_csn    = {pin.FLASH_SSB}
$$pin.sf_mosi   = {pin.FLASH_IO0} pin.sf_miso   = {pin.FLASH_IO1}
$$pin.sf_io0    = {pin.FLASH_IO0} pin.sf_io1    = {pin.FLASH_IO1}
$$pin.sf_io2    = {pin.FLASH_IO2} pin.sf_io3    = {pin.FLASH_IO3}
$$pin.ram_clk   = {pin.P1A4} pin.ram_csn   = {pin.P1A1}
$$pin.ram_io0   = {pin.P1A2} pin.ram_io1   = {pin.P1A3}
$$pin.ram_io2   = {pin.P1A7} pin.ram_io3   = {pin.P1A8}
$$pin.ram_bank  = {pin.P1A10,pin.P1A9}
$$pin.extras    = {pin.P1B10,pin.P1B9,pin.RGB_B,pin.RGB_G,pin.RGB_R}
$$pin.prlscreen_d    = {pin.P2_10,pin.P1B10,pin.P2_8,pin.P2_7,pin.P2_4,pin.P1B4,pin.P2_2,pin.P2_1}
$$pin.prlscreen_resn = {pin.P1B2} pin.prlscreen_csn  = {pin.P1B8}
$$pin.prlscreen_rs   = {pin.P1B3} pin.prlscreen_clk  = {pin.P1B9}
$$pin.pmdpi_csn  = {pin.P1A7} pin.pmdpi_clk  = {pin.P1A10}
$$pin.pmdpi_io0  = {pin.P1A8} pin.pmdpi_io1  = {pin.P1A9}
//
$$NUM_LEDS = 5
$$NUM_BTNS = 3

module top(
  %TOP_SIGNATURE%
  input  CLK
  );

// clock from design is used in case
// it relies on a PLL: in such cases
// we cannot use the clock fed into
// the PLL here
wire design_clk;

// reset management
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

%WIRE_DECL%

M_main __main(
  .clock(CLK),
  .out_clock(design_clk),
  .reset(~RST_q[23]),
  %MAIN_GLUE%
  .in_run(run_main)
);

endmodule
