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
    inout [7:0]   sdram_dq,
    // HDMI
    output [3:0] gpdi_dp,
    output [3:0] gpdi_dn,
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
// assign gpdi_dp       = __main_out_gpdi_dp;
// assign gpdi_dn       = __main_out_gpdi_dn;
/*
OBUFDS gpdi_pairs[3:0](
  .I (__main_out_gpdi_dp),
  .O (gpdi_dp),
  .OB(gpdi_dn)
);
*/
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
assign gpdi_dp       = 4'bzzzz;
assign gpdi_dn       = 4'bzzzz;
`endif
  
endmodule
