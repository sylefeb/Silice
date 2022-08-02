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
`define ICARUS 1
$$ICARUS      = 1
$$SIMULATION  = 1
$$NUM_LEDS    = 8
$$color_depth = 6
$$color_max   = 63
$$config['bram_wenable_width'] = '1'
$$config['dualport_bram_wenable0_width'] = 'data'
$$config['dualport_bram_wenable1_width'] = 'data'
$$config['reg_init_zero'] = '1'

`timescale 1ns / 1ps

module top;

reg clk;
reg rst_n;

wire [7:0] __main_leds;

`ifdef VGA
wire __main_video_clock;
wire __main_video_hs;
wire __main_video_vs;
wire [5:0] __main_video_r;
wire [5:0] __main_video_g;
wire [5:0] __main_video_b;
`endif

`ifdef UART
wire __main_uart_tx;
wire __main_uart_rx = 0;
`endif

`ifdef HDMI
wire [3:0] __main_out_gpdi_dp;
wire [3:0] __main_out_gpdi_dn;
`endif

`ifdef SDCARD
wire        __main_sd_clk;
wire        __main_sd_csn;
wire        __main_sd_mosi;
`endif

initial begin
  clk = 1'b0;
  rst_n = 1'b0;
  $display("icarus framework started");
  $dumpfile("trace.fst");
`ifdef DUMP_TOP_ONLY
  $dumpvars(1,top); // dump only top (faster and smaller)
`else
  $dumpvars(0,top); // dump all (for full debugging)
`endif
`ifdef CLOCK_25MHz
  // generate a 25 MHz clock
  repeat(100) #20 clk = ~clk;
  rst_n = 1'b1;
  forever #20 clk = ~clk;
`else
  // generate a 100 MHz clock
  repeat(100) #5 clk = ~clk;
  rst_n = 1'b1;
  forever #5 clk = ~clk;
`endif
end

wire run_main;
assign run_main = 1'b1;
wire done_main;

M_main __main(
  .clock(clk),
  .reset(~rst_n),
  .out_leds(__main_leds),
`ifdef VGA
  .out_video_clock(__main_video_clock),
  .out_video_r(__main_video_r),
  .out_video_g(__main_video_g),
  .out_video_b(__main_video_b),
  .out_video_hs(__main_video_hs),
  .out_video_vs(__main_video_vs),
`endif
`ifdef SDCARD
  .out_sd_csn    (__main_sd_csn),
  .out_sd_clk    (__main_sd_clk),
  .out_sd_mosi   (__main_sd_mosi),
  .in_sd_miso    (1'b0),
`endif
`ifdef UART
  .out_uart_tx(__main_uart_tx),
  .in_uart_rx(__main_uart_rx),
`endif
`ifdef HDMI
  .out_gpdi_dp  (__main_out_gpdi_dp),
  .out_gpdi_dn  (__main_out_gpdi_dn),
`endif
  .in_run(run_main),
  .out_done(done_main)
);

always @* begin
  if (done_main && ~rst_n) $finish;
end

endmodule
