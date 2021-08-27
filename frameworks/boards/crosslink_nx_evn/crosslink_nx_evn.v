/*

Copyright 2019, (C) Gwenhael Goavec-Merou and contributors
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

`define CROSSLINKNX_EVN 1
$$CROSSLINKNX_EVN=1
$$HARDWARE=1
$$NUM_LEDS=5
$$VGA=1
$$color_depth=6
$$color_max  =63
$$config['bram_wenable_width'] = 'data'
$$config['dualport_bram_wenable0_width'] = 'data'
$$config['dualport_bram_wenable1_width'] = 'data'

module top(
  output LED0,
  output LED1,
  output LED2,
  output LED3,
  output LED4,
`ifdef VGA
  output PMOD0_1, // r0
  output PMOD0_2, // r1
  output PMOD0_3, // r2
  output PMOD0_4, // r3
  
  output PMOD0_7, // b0
  output PMOD0_8, // b1
  output PMOD0_9, // b2
  output PMOD0_10,// b3
  
  output PMOD1_1, // g0
  output PMOD1_2, // g1
  output PMOD1_3, // g2
  output PMOD1_4, // g3
  
  output PMOD1_7, // hs
  output PMOD1_8, // vs
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
`endif

BB u0_BB (.B(CLK),
	.I(1'b0),
	.T(1'b1),
	.O(clk_s)
);

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
  .clock(clk_s),
  .out_clock(design_clk),
  .reset(RST_d[0]),
  .out_leds(__main_leds),
`ifdef VGA
  .out_video_hs(__main_out_vga_hs),
  .out_video_vs(__main_out_vga_vs),
  .out_video_r(__main_out_vga_r),
  .out_video_g(__main_out_vga_g),
  .out_video_b(__main_out_vga_b),
`endif
  .in_run(run_main)
);

assign LED0 = __main_leds[0+:1];
assign LED1 = __main_leds[1+:1];
assign LED2 = __main_leds[2+:1];
assign LED3 = __main_leds[3+:1];
assign LED4 = __main_leds[4+:1];

// VGA

`ifdef VGA

assign PMOD0_1  = __main_out_vga_r[2+:1];
assign PMOD0_2  = __main_out_vga_r[3+:1];
assign PMOD0_3  = __main_out_vga_r[4+:1];
assign PMOD0_4  = __main_out_vga_r[5+:1];

assign PMOD0_7  = __main_out_vga_b[2+:1];
assign PMOD0_8  = __main_out_vga_b[3+:1];
assign PMOD0_9  = __main_out_vga_b[4+:1];
assign PMOD0_10 = __main_out_vga_b[5+:1];

assign PMOD1_1  = __main_out_vga_g[2+:1];
assign PMOD1_2  = __main_out_vga_g[3+:1];
assign PMOD1_3  = __main_out_vga_g[4+:1];
assign PMOD1_4  = __main_out_vga_g[5+:1];

assign PMOD1_7  = __main_out_vga_hs;
assign PMOD1_8  = __main_out_vga_vs;

`endif

endmodule
