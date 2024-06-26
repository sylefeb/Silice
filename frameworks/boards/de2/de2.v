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

`define DE2 1
$$DE2 = 1
$$HARDWARE = 1
$$NUM_LEDS = 27
$$NUM_BTNS = 4
$$config['dualport_bram_template'] = 'dualport_bram_altera.v.in'
$$color_depth = 10
$$color_max   = 1023
$$SDRAM_COLUMNS_WIDTH = 9

module top(
    output [26:0] leds,
`ifdef BUTTONS
    // buttons
    input  [3:0] btns,
`endif
`ifdef SDRAM
    // sdram
    output  SDRAM_CLK,
    output  SDRAM_CKE,
    output  SDRAM_DQML,
    output  SDRAM_DQMH,
    output  SDRAM_nCS,
    output  SDRAM_nWE,
    output  SDRAM_nCAS,
    output  SDRAM_nRAS,
    output  [1:0] SDRAM_BA,
    output  [11:0] SDRAM_A,
    inout   [15:0] SDRAM_DQ,
`endif
`ifdef VGA
    // vga
    output  vga_hs,
    output  vga_vs,
    output  vga_clock,
    output  vga_blank,
    output  vga_sync,
    output  [9:0] vga_r,
    output  [9:0] vga_g,
    output  [9:0] vga_b,
`endif
`ifdef UART
    // uart
    input  uart_rx,
    output uart_tx,
`endif
`ifdef UART2
    // uart, second choice
    input  uart2_rx,
    output uart2_tx,
`endif
`ifdef KEYPAD
    // keypad
    output  [3:0] kpadC,
    input   [3:0] kpadR,
`endif
    // hex
    output [6:0] hex0,
    output [6:0] hex1,
    output [6:0] hex2,
    output [6:0] hex3,
    output [6:0] hex4,
    output [6:0] hex5,
    output [6:0] hex6,
    output [6:0] hex7,
    // clock
    input clk
);

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
`ifdef UART2
wire        __main_out_uart_tx;
`endif

`ifdef KEYPAD
wire [3:0]  __main_out_kpadC;
`endif

// reset

reg [31:0] RST_d;
reg [31:0] RST_q;

reg ready = 0;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge clk) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 32'b111111111111111111111111111111;
  end
end

wire reset_main;
assign reset_main = RST_q[0];
wire run_main;
assign run_main = 1'b1;

M_main __main(
  .reset(reset_main),
  .in_run(run_main),
  .out_leds(leds),
`ifdef BUTTONS
  .in_btns(btns),
`endif
`ifdef SDRAM
  .inout_sdram_dq(SDRAM_DQ),
  .out_sdram_clk(__main_out_sdram_clk),
  .out_sdram_cle(__main_out_sdram_cle),
  .out_sdram_dqm(__main_out_sdram_dqm),
  .out_sdram_cs(__main_out_sdram_cs),
  .out_sdram_we(__main_out_sdram_we),
  .out_sdram_cas(__main_out_sdram_cas),
  .out_sdram_ras(__main_out_sdram_ras),
  .out_sdram_ba(__main_out_sdram_ba),
  .out_sdram_a(__main_out_sdram_a),
`endif
`ifdef VGA
  .out_video_hs(vga_hs),
  .out_video_vs(vga_vs),
  .out_video_r(vga_r),
  .out_video_g(vga_g),
  .out_video_b(vga_b),
  .out_video_clock(vga_clock),
`endif
`ifdef UART
  .out_uart_tx(__main_out_uart_tx),
  .in_uart_rx(uart_rx),
`endif
`ifdef UART2
  .out_uart_tx(__main_out_uart_tx),
  .in_uart_rx(uart2_rx),
`endif
`ifdef KEYPAD
  .out_kpadC(__main_out_kpadC),
  .in_kpadR(kpadR),
`endif
  .clock(clk)
);

`ifdef SDRAM
assign  SDRAM_CLK    = __main_out_sdram_clk;
assign  SDRAM_CKE    = __main_out_sdram_cle;
assign  SDRAM_DQML   = __main_out_sdram_dqm[0];
assign  SDRAM_DQMH   = __main_out_sdram_dqm[1];
assign  SDRAM_nCS    = __main_out_sdram_cs;
assign  SDRAM_nWE    = __main_out_sdram_we;
assign  SDRAM_nCAS   = __main_out_sdram_cas;
assign  SDRAM_nRAS   = __main_out_sdram_ras;
assign  SDRAM_BA     = __main_out_sdram_ba;
assign  SDRAM_A      = __main_out_sdram_a[11:0];
`endif

`ifdef VGA
assign  vga_blank    = 1'b1;
assign  vga_synch    = 1'b0;
`endif

`ifdef UART
assign uart_tx       = __main_out_uart_tx;
`endif
`ifdef UART2
assign uart2_tx      = __main_out_uart_tx;
`endif

`ifdef KEYPAD
assign  kpadC        = __main_out_kpadC;
`endif

assign hex0 = 7'b1111111;
assign hex1 = 7'b1111111;
assign hex2 = 7'b0000110; // E
assign hex3 = 7'b1000110; // C
assign hex4 = 7'b1001111; // I
assign hex5 = 7'b1000111; // L
assign hex6 = 7'b1001111; // I
assign hex7 = 7'b0010010; // S
//               ABCDEFG

endmodule
