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

`define ECPIX5 1
$$ECPIX5   = 1
$$HARDWARE = 1
$$NUM_LEDS = 12
$$color_depth=6
$$color_max  =63
$$config['dualport_bram_supported'] = 'no'
`default_nettype none

module top(
  // basic
  output [11:0] leds,
`ifdef UART
  // uart
  output  uart_rx,
  input   uart_tx,
`endif
`ifdef VGA
  output P0A1, // r0
  output P0A2, // r1
  output P0A3, // r2
  output P0A4, // r3
  
  output P0A7,   // b0
  output P0A8,   // b1
  output P0A9,   // b2
  output P0A10,  // b3
  
  output P1A1,  // g0
  output P1A2,  // g1
  output P1A3,  // g2
  output P1A4,  // g3
  
  output P1A7,  // hs
  output P1A8,  // vs
`endif
  input  clk100
  );

reg ready = 0;

reg [31:0] RST_d;
reg [31:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge clk100) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 32'b111111111111111111111111111111;
  end
end

wire [11:0] __main_leds;

`ifdef VGA
wire __main_out_vga_hs;
wire __main_out_vga_vs;
wire __main_out_vga_v0;
wire [5:0] __main_out_vga_r;
wire [5:0] __main_out_vga_g;
wire [5:0] __main_out_vga_b;
`endif  

wire run_main;
assign run_main = 1'b1;

M_main __main(
  .reset         (RST_q[0]),
  .in_run        (run_main),
  .out_leds      (__main_leds),
`ifdef UART
  .out_uart_tx  (uart_tx),
  .in_uart_rx   (uart_rx),
`endif  
`ifdef VGA
  .out_video_hs(__main_out_vga_hs),
  .out_video_vs(__main_out_vga_vs),
  .out_video_r(__main_out_vga_r),
  .out_video_g(__main_out_vga_g),
  .out_video_b(__main_out_vga_b),
`endif
  .clock         (clk100)
);

assign leds = ~__main_leds;

`ifdef VGA
assign P0A1  = __main_out_vga_r[2+:1];
assign P0A2  = __main_out_vga_r[3+:1];
assign P0A3  = __main_out_vga_r[4+:1];
assign P0A4  = __main_out_vga_r[5+:1];

assign P0A7  = __main_out_vga_b[2+:1];
assign P0A8  = __main_out_vga_b[3+:1];
assign P0A9  = __main_out_vga_b[4+:1];
assign P0A10 = __main_out_vga_b[5+:1];

assign P1A1  = __main_out_vga_g[2+:1];
assign P1A2  = __main_out_vga_g[3+:1];
assign P1A3  = __main_out_vga_g[4+:1];
assign P1A4  = __main_out_vga_g[5+:1];

assign P1A7  = __main_out_vga_hs;
assign P1A8  = __main_out_vga_vs;
`endif

endmodule

