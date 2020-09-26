`define ULX3S 1
`default_nettype none
$$ULX3S    = 1
$$HARDWARE = 1
$$SDRAM    = 1
$$SDCARD   = 1
$$HDMI     = 1
$$color_depth = 8
$$color_max   = 255

module top(
  input  clk_25mhz,
  output [7:0] led,
  input  [6:0] btn,
  // SDRAM
  output sdram_clk,
  output sdram_cke,
  output [1:0]  sdram_dqm,
  output sdram_csn,
  output sdram_wen,
  output sdram_casn,
  output sdram_rasn,
  output [1:0]  sdram_ba,
  output [12:0] sdram_a,
  inout  [15:0] sdram_d,
  // sdcard
  output  sd_clk,
  output  sd_csn,
  output  sd_mosi,
  input   sd_miso,
  // GPDI (video) differential pairs
  output [3:0]  gpdi_dp, // {clock,R,G,B}
  output [3:0]  gpdi_dn,
  );

wire [7:0]  __main_out_led;

wire        __main_out_sdram_clk;
wire        __main_out_sdram_cle;
wire [1:0]  __main_out_sdram_dqm;
wire        __main_out_sdram_cs;
wire        __main_out_sdram_we;
wire        __main_out_sdram_cas;
wire        __main_out_sdram_ras;
wire [1:0]  __main_out_sdram_ba;
wire [12:0] __main_out_sdram_a;
  
wire [2:0]  __main_out_gpdi_dp;
wire [2:0]  __main_out_gpdi_dn;

wire        __main_sd_clk;
wire        __main_sd_csn;
wire        __main_sd_mosi;

// reg ready = 0;
wire ready = btn[0];

reg [31:0] RST_d;
reg [31:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge clk_25mhz) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    // ready <= 1;
    RST_q <= 32'b111111111111111111111111111111;
  end
end

wire run_main;
assign run_main = 1'b1;

M_main __main(
  .clock         (clk_25mhz),
  .reset         (RST_q[0]),
  .out_led       (__main_out_led),
  .inout_sdram_dq(sdram_d[7:0]),
  .out_sdram_clk (__main_out_sdram_clk),
  .out_sdram_cle (__main_out_sdram_cle),
  .out_sdram_dqm (__main_out_sdram_dqm),
  .out_sdram_cs  (__main_out_sdram_cs),
  .out_sdram_we  (__main_out_sdram_we),
  .out_sdram_cas (__main_out_sdram_cas),
  .out_sdram_ras (__main_out_sdram_ras),
  .out_sdram_ba  (__main_out_sdram_ba),
  .out_sdram_a   (__main_out_sdram_a),
  .out_sd_csn    (__main_sd_csn),
  .out_sd_clk    (__main_sd_clk),
  .out_sd_mosi   (__main_sd_mosi),
  .in_sd_miso    (sd_miso),
  .out_gpdi_dp   (__main_out_gpdi_dp),
  .out_gpdi_dn   (__main_out_gpdi_dn),
  .in_btn        (btn),
  .in_run        (run_main)
);

assign led           = __main_out_led;

assign sdram_clk     = __main_out_sdram_clk;
assign sdram_cke     = __main_out_sdram_cle;
assign sdram_dqm     = __main_out_sdram_dqm;
assign sdram_csn     = __main_out_sdram_cs;
assign sdram_wen     = __main_out_sdram_we;
assign sdram_casn    = __main_out_sdram_cas;
assign sdram_rasn    = __main_out_sdram_ras;
assign sdram_ba      = __main_out_sdram_ba;
assign sdram_a       = __main_out_sdram_a;

assign gpdi_dp[0+:3] = __main_out_gpdi_dp;
assign gpdi_dn[0+:3] = __main_out_gpdi_dn;

assign sd_clk        = __main_sd_clk;
assign sd_csn        = __main_sd_csn;
assign sd_mosi       = __main_sd_mosi;

OBCO dp(.I(clk_25mhz), .OT(gpdi_dp[3]), .OC(gpdi_dn[3]) );

endmodule
