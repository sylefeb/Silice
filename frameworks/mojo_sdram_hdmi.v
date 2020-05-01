`define MOJO 1
$$MOJO=1
$$HDMI=1
$$HARDWARE=1
$$SDRAM=1

module mojo_top(
    input clk,
    input rst_n,
    input cclk,
    output reg[7:0] led,
    output reg spi_miso,
    input spi_ss,
    input spi_mosi,
    input spi_sck,
    output reg[3:0] spi_channel,
    input avr_tx,
    output reg avr_rx,
    input avr_rx_busy,
    // SDRAM
    output reg sdram_clk,
    output reg sdram_cle,
    output reg sdram_dqm,
    output reg sdram_cs,
    output reg sdram_we,
    output reg sdram_cas,
    output reg sdram_ras,
    output reg [1:0] sdram_ba,
    output reg [12:0] sdram_a,
    inout [7:0] sdram_dq,
    // HDMI
    output reg [3:0] hdmi1_tmds,
    output reg [3:0] hdmi1_tmdsb
    );

wire [7:0]  __main_out_led;

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
wire [3:0]  __main_out_hdmi1_tmds;
wire [3:0]  __main_out_hdmi1_tmdsb;

wire run_main;
assign run_main = 1'b1;

M_main __main(
  .clock(clk),
  .reset(~rst_n),
  .in_run(run_main),
  .inout_sdram_dq(sdram_dq),
  .in_spi_ss(spi_ss),
  .in_spi_sck(spi_sck),
  .in_avr_tx(avr_tx),
  .in_avr_rx_busy(avr_rx_busy),
  .in_spi_mosi(spi_mosi),
  .out_spi_miso(__main_spi_miso),
  .out_avr_rx(__main_out_avr_rx),
  .out_spi_channel(__main_out_spi_channel),
  .out_led(__main_out_led),
  .out_sdram_clk(__main_out_sdram_clk),
  .out_sdram_cle(__main_out_sdram_cle),
  .out_sdram_dqm(__main_out_sdram_dqm),
  .out_sdram_cs(__main_out_sdram_cs),
  .out_sdram_we(__main_out_sdram_we),
  .out_sdram_cas(__main_out_sdram_cas),
  .out_sdram_ras(__main_out_sdram_ras),
  .out_sdram_ba(__main_out_sdram_ba),
  .out_sdram_a(__main_out_sdram_a),
  .out_hdmi1_tmds(__main_out_hdmi1_tmds),
  .out_hdmi1_tmdsb(__main_out_hdmi1_tmdsb)
);

always @* begin

  spi_miso     = __main_spi_miso;
  avr_rx       = __main_out_avr_rx;
  spi_channel  = __main_out_spi_channel;
  
  led          = __main_out_led;
  
  sdram_clk    = __main_out_sdram_clk;
  sdram_cle    = __main_out_sdram_cle;
  sdram_dqm    = __main_out_sdram_dqm;
  sdram_cs     = __main_out_sdram_cs;
  sdram_we     = __main_out_sdram_we;
  sdram_cas    = __main_out_sdram_cas;
  sdram_ras    = __main_out_sdram_ras;
  sdram_ba     = __main_out_sdram_ba;
  sdram_a      = __main_out_sdram_a;
  
  hdmi1_tmds   = __main_out_hdmi1_tmds;
  hdmi1_tmdsb  = __main_out_hdmi1_tmdsb;
  
end

endmodule
