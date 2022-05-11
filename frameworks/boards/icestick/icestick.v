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
`default_nettype none
$$ICESTICK=1
$$HARDWARE=1
$$NUM_LEDS=5
$$VGA=1
$$color_depth=6
$$color_max  =63
$$config['bram_wenable_width'] = '1'
$$config['dualport_bram_wenable0_width'] = '1'
$$config['dualport_bram_wenable1_width'] = '1'
$$config['simple_dualport_bram_wenable0_width'] = '1'
$$config['simple_dualport_bram_wenable1_width'] = '1'

module top(
  output D1,
  output D2,
  output D3,
  output D4,
  output D5,
`ifdef OLED
  output PMOD1,
  output PMOD7,
  output PMOD8,
  output PMOD9,
  output PMOD10,
`endif
`ifdef PMOD
  inout PMOD1,
  inout PMOD2,
  inout PMOD3,
  inout PMOD4,
  inout PMOD7,
  inout PMOD8,
  inout PMOD9,
  inout PMOD10,
`endif
`ifdef PMOD_OUT
  output PMOD1,
  output PMOD2,
  output PMOD3,
  output PMOD4,
  output PMOD7,
  output PMOD8,
  output PMOD9,
  output PMOD10,
`endif
`ifdef UART
  // uart
  input   RX,
  output  TX,
`endif
`ifdef VGA
  output PMOD1, // r0
  output PMOD2, // r1
  output PMOD3, // r2
  output PMOD4, // r3
  output PMOD8, // r4
  output PMOD9, // r5

  output TR10, // g0
  output TR9,  // g1
  output TR8,  // g2
  output TR7,  // g3
  output TR6,  // g4
  output TR5,  // g5

  output BR10, // b0
  output BR9,  // b1
  output BR8,  // b2
  output BR7,  // b3
  output BR6,  // b4
  output BR5,  // b5

  output PMOD7,  // hs
  output PMOD10, // vs
`endif
`ifdef SPIFLASH
  output FLASH_CLK,
  output FLASH_MOSI,
  input  FLASH_MISO,
  output FLASH_CSN,
`endif
  input  CLK
  );

wire [4:0] __main_leds;

`ifdef OLED
wire __main_oled_clk;
wire __main_oled_mosi;
wire __main_oled_csn;
wire __main_oled_resn;
wire __main_oled_dc;
`ifdef VGA
`error_cannot_use_both_OLED_and_VGA_not_enough_pins
`endif
`ifdef PMOD
`error_cannot_use_both_PMOD_and_OLED_not_enough_pins
`endif
`ifdef PMOD_OUT
`error_cannot_use_both_PMOD_and_OLED_not_enough_pins
`endif
`endif

`ifdef VGA
wire __main_out_vga_hs;
wire __main_out_vga_vs;
wire __main_out_vga_v0;
wire [5:0] __main_out_vga_r;
wire [5:0] __main_out_vga_g;
wire [5:0] __main_out_vga_b;
`ifdef OLED
`error_cannot_use_both_OLED_and_VGA_not_enough_pins
`endif
`ifdef PMOD
`error_cannot_use_both_PMOD_and_VGA_not_enough_pins
`endif
`ifdef PMOD_OUT
`error_cannot_use_both_PMOD_and_OLED_not_enough_pins
`endif
`endif

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

M_main __main(
  .clock(CLK),
  .reset(~RST_q[23]),
  .out_leds(__main_leds),
`ifdef OLED
  .out_oled_mosi(__main_oled_mosi),
  .out_oled_clk(__main_oled_clk),
  .out_oled_csn(__main_oled_csn),
  .out_oled_dc(__main_oled_dc),
  .out_oled_resn(__main_oled_resn),
`endif
`ifdef VGA
  .out_video_hs(__main_out_vga_hs),
  .out_video_vs(__main_out_vga_vs),
  .out_video_r(__main_out_vga_r),
  .out_video_g(__main_out_vga_g),
  .out_video_b(__main_out_vga_b),
`endif
`ifdef PMOD
  .inout_pmod({PMOD10,PMOD9,PMOD8,PMOD7,PMOD4,PMOD3,PMOD2,PMOD1}),
`endif
`ifdef PMOD_OUT
  .out_pmod  ({PMOD10,PMOD9,PMOD8,PMOD7,PMOD4,PMOD3,PMOD2,PMOD1}),
`endif
`ifdef UART
  .out_uart_tx  (TX),
  .in_uart_rx   (RX),
`endif
`ifdef SPIFLASH
  .out_sf_clk (FLASH_CLK),
  .out_sf_csn (FLASH_CSN),
  .out_sf_mosi(FLASH_MOSI),
  .in_sf_miso (FLASH_MISO),
`endif
  .in_run(run_main)
);

assign D1 = __main_leds[0+:1];
assign D2 = __main_leds[1+:1];
assign D3 = __main_leds[2+:1];
assign D4 = __main_leds[3+:1];
assign D5 = __main_leds[4+:1];

// OLED

`ifdef OLED

assign PMOD10 = __main_oled_mosi;
assign PMOD9  = __main_oled_clk;
assign PMOD8  = __main_oled_csn;
assign PMOD7  = __main_oled_dc;
assign PMOD1  = __main_oled_resn;

`endif

// VGA

`ifdef VGA

assign PMOD1  = __main_out_vga_r[5+:1];
assign PMOD2  = __main_out_vga_r[4+:1];
assign PMOD3  = __main_out_vga_r[3+:1];
assign PMOD4  = __main_out_vga_r[2+:1];
assign PMOD8  = __main_out_vga_r[1+:1];
assign PMOD9  = __main_out_vga_r[0+:1];

assign TR10   = __main_out_vga_g[5+:1];
assign TR9    = __main_out_vga_g[4+:1];
assign TR8    = __main_out_vga_g[3+:1];
assign TR7    = __main_out_vga_g[2+:1];
assign TR6    = __main_out_vga_g[1+:1];
assign TR5    = __main_out_vga_g[0+:1];

assign BR10   = __main_out_vga_b[5+:1];
assign BR9    = __main_out_vga_b[4+:1];
assign BR8    = __main_out_vga_b[3+:1];
assign BR7    = __main_out_vga_b[2+:1];
assign BR6    = __main_out_vga_b[1+:1];
assign BR5    = __main_out_vga_b[0+:1];

assign PMOD7  = __main_out_vga_hs;
assign PMOD10 = __main_out_vga_vs;

`endif


endmodule
