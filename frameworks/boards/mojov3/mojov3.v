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
`define MOJO 1
$$MOJO=1
$$HARDWARE = 1
$$NUM_LEDS = 8
$$NUM_BTNS = 1
$$color_depth = 6
$$color_max   = 63

module top(
    input  rst_n,
    input  cclk,
    output [7:0] leds,
    output spi_miso,
    input  spi_ss,
    input  spi_mosi,
    input  spi_sck,
    output [3:0] spi_channel,
    input  avr_tx,
    output avr_rx,
    input  avr_rx_busy,
    // SDRAM
    output sdram_clk,
    output sdram_cle,
    output sdram_dqm,
    output sdram_cs,
    output sdram_we,
    output sdram_cas,
    output sdram_ras,
    output [1:0]  sdram_ba,
    output [12:0] sdram_a,
    inout  [7:0]  sdram_dq,
    // HDMI
    output [3:0] gpdi_dp,
    output [3:0] gpdi_dn,
    // HDMI IN
    input  [3:0] gpdi_in_dp,
    input  [3:0] gpdi_in_dn,
    input        gpdi_in_scl,
    inout        gpdi_in_sda,
    input clk
    );

wire [7:0]  __main_out_leds;

wire        __main_spi_miso;
wire        __main_out_avr_rx;
wire [3:0]  __main_out_spi_channel;

wire        __main_out_sdram_clk;
wire        __main_out_sdram_cle;
wire        __main_out_sdram_dqm;
wire        __main_out_sdram_cs;
wire        __main_out_sdram_we;
wire        __main_out_sdram_cas;
wire        __main_out_sdram_ras;
wire [1:0]  __main_out_sdram_ba;
wire [12:0] __main_out_sdram_a;

wire run_main;
assign run_main = 1'b1;

wire [3:0] __main_out_gpdi_dp;

M_main __main(
  .reset(~rst_n),
  .in_run(run_main),
  .out_leds(__main_out_leds),
`ifdef SDRAM
  .inout_sdram_dq(sdram_dq),
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
`ifdef HDMI
  .out_gpdi_dp  (__main_out_gpdi_dp),
//  .out_gpdi_dn  (__main_out_gpdi_dn),
`endif
`ifdef HDMI_IN
  .in_gpdi_in_dp    (gpdi_in_dp),
  .in_gpdi_in_dn    (gpdi_in_dn),
  .in_gpdi_in_scl   (gpdi_in_scl),
  .inout_gpdi_in_sca(gpdi_in_sca),
`endif
  .clock(clk)
);

assign spi_miso    = 1'bz;
assign avr_rx      = 1'bz;
assign spi_channel = 4'bzzzz;

assign leds        = __main_out_leds;
  
`ifdef SDRAM
assign sdram_clk     = __main_out_sdram_clk;
assign sdram_cle     = __main_out_sdram_cle;
assign sdram_dqm     = __main_out_sdram_dqm;
assign sdram_cs      = __main_out_sdram_cs;
assign sdram_we      = __main_out_sdram_we;
assign sdram_cas     = __main_out_sdram_cas;
assign sdram_ras     = __main_out_sdram_ras;
assign sdram_ba      = __main_out_sdram_ba;
assign sdram_a       = __main_out_sdram_a;
`else
assign sdram_clk     = 1'bz;
assign sdram_cle     = 1'bz;
assign sdram_dqm     = 1'bz;
assign sdram_cs      = 1'bz;
assign sdram_we      = 1'bz;
assign sdram_cas     = 1'bz;
assign sdram_ras     = 1'bz;
assign sdram_ba      = 2'bzz;
assign sdram_a       = 12'bzzzzzzzzzzzz;
`endif
  
`ifdef HDMI
OBUFDS gpdi_pairs_0(
  .I (__main_out_gpdi_dp[0]),
  .O (gpdi_dp[0]),
  .OB(gpdi_dn[0])
);
OBUFDS gpdi_pairs_1(
  .I (__main_out_gpdi_dp[1]),
  .O (gpdi_dp[1]),
  .OB(gpdi_dn[1])
);
OBUFDS gpdi_pairs_2(
  .I (__main_out_gpdi_dp[2]),
  .O (gpdi_dp[2]),
  .OB(gpdi_dn[2])
);
OBUFDS gpdi_pairs_3(
  .I (__main_out_gpdi_dp[3]),
  .O (gpdi_dp[3]),
  .OB(gpdi_dn[3])
);
`else
OBUFDS gpdi_pairs[3:0](
  .I (1'b0),
  .O (gpdi_dp),
  .OB(gpdi_dn)
);
`endif

`ifdef HDMI_IN

`else
wire [3:0] gpdi_in_unused;
IBUFDS gpdi_pairs[3:0](
  .O (gpdi_in_unused),
  .I (gpdi_in_dp),
  .IB(gpdi_in_dn)
);
assign gpdi_in_sda = 1'bz;
`endif


endmodule
