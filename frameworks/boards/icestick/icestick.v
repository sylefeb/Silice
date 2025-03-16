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
`define ICESTICK 1
`define ICE40 1
`default_nettype none
$$ICESTICK=1
$$ICE40=1
$$HARDWARE=1
$$VGA=1
$$color_depth=6
$$color_max  =63
$$config['bram_wenable_width'] = '1'
$$config['dualport_bram_wenable0_width'] = '1'
$$config['dualport_bram_wenable1_width'] = '1'
$$config['simple_dualport_bram_wenable0_width'] = '1'
$$config['simple_dualport_bram_wenable1_width'] = '1'
$$config['allow_deprecated_framework'] = 'no'
// declare package pins (has to match the hardware pin definition)
// pin.NAME = <WIDTH>
$$pin.D1 = 1 pin.D2 = 1 pin.D3 = 1 pin.D4 = 1 pin.D5 = 1
$$pin.PMOD1=1 pin.PMOD2=1 pin.PMOD3=1 pin.PMOD4=1
$$pin.PMOD7=1 pin.PMOD8=1 pin.PMOD9=1 pin.PMOD10=1
$$pin.RX=1 pin.TX=1
$$pin.TR3=1 pin.TR4=1 pin.TR5=1 pin.TR6=1 pin.TR7=1 pin.TR8=1 pin.TR9=1 pin.TR10=1
$$pin.BR5=1 pin.BR6=1 pin.BR7=1 pin.BR8=1 pin.BR9=1 pin.BR10=1
$$pin.FLASH_CLK=1 pin.FLASH_MOSI=1 pin.FLASH_MISO=1 pin.FLASH_CSN=1
// pin groups and renaming
$$pin.leds      = {pin.D5,pin.D4,pin.D3,pin.D2,pin.D1}
$$pin.oled_mosi = {pin.PMOD10} pin.oled_clk  = {pin.PMOD9}
$$pin.oled_csn  = {pin.PMOD8}  pin.oled_dc   = {pin.PMOD7}
$$pin.oled_resn = {pin.PMOD1}
$$pin.vga_r     = {pin.PMOD1,pin.PMOD2,pin.PMOD3,pin.PMOD4,pin.PMOD8,pin.PMOD9}
$$pin.vga_g     = {pin.TR10,pin.TR9,pin.TR8,pin.TR7,pin.TR6,pin.TR5}
$$pin.vga_b     = {pin.BR10,pin.BR9,pin.BR8,pin.BR7,pin.BR6,pin.BR5}
$$pin.vga_hs    = {pin.PMOD7}
$$pin.vga_vs    = {pin.PMOD10}
$$pin.video_r   = {pin.PMOD1,pin.PMOD2,pin.PMOD3,pin.PMOD4,pin.PMOD8,pin.PMOD9}
$$pin.video_g   = {pin.TR10,pin.TR9,pin.TR8,pin.TR7,pin.TR6,pin.TR5}
$$pin.video_b   = {pin.BR10,pin.BR9,pin.BR8,pin.BR7,pin.BR6,pin.BR5}
$$pin.video_hs  = {pin.PMOD7}
$$pin.video_vs  = {pin.PMOD10}
$$pin.pmod      = {pin.PMOD10,pin.PMOD9,pin.PMOD8,pin.PMOD7,pin.PMOD4,pin.PMOD3,pin.PMOD2,pin.PMOD1}
$$pin.uart_tx   = {pin.TX}
$$pin.uart_rx   = {pin.RX}
$$pin.sf_clk    = {pin.FLASH_CLK}  pin.sf_csn    = {pin.FLASH_CSN}
$$pin.sf_mosi   = {pin.FLASH_MOSI} pin.sf_miso   = {pin.FLASH_MISO}
$$pin.ram_io0   = {pin.PMOD2} pin.ram_io1 = {pin.PMOD3}
$$pin.ram_io2   = {pin.PMOD7} pin.ram_io3 = {pin.PMOD8}
$$pin.ram_clk   = {pin.PMOD4} pin.ram_csn = {pin.PMOD1}
$$pin.ram_bank  = {pin.PMOD10,pin.PMOD9}
$$pin.spiscreen_mosi = {pin.TR3}
$$pin.spiscreen_clk  = {pin.TR4}
$$pin.spiscreen_csn  = {pin.TR5}
$$pin.spiscreen_dc   = {pin.TR6}
$$pin.spiscreen_resn = {pin.TR7}
//
$$NUM_LEDS=5

module top(
  %TOP_SIGNATURE%
  input  CLK
  );

// the init sequence pauses for some cycles
// waiting for BRAM init to stabalize
// this is a known issue with ice40 FPGAs
// https://github.com/YosysHQ/icestorm/issues/76

reg ready = 0;
reg [23:0] RST_d;
reg [23:0] RST_q;

always @* begin
  RST_d = RST_q[23] ? RST_q : RST_q + 1;
end

always @(posedge CLK) begin
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
  .reset(~RST_q[23]),
  %MAIN_GLUE%
  .in_run(run_main)
);

endmodule
