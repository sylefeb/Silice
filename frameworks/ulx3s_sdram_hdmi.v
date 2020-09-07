`define ULX3S 1
`default_nettype none
$$ULX3S=1
$$HARDWARE=1
$$HDMI=1
$$color_depth=6
$$color_max  =63
$$SDRAM=1

module top(
  input  clk_25mhz,
  output [7:0] led,
  input  [6:0] btn,
  // SDRAM
  output sdram_clk,
  output sdram_cke,
  output [1:0] sdram_dqm,
  output sdram_csn,
  output sdram_wen,
  output sdram_casn,
  output sdram_rasn,
  output [1:0] sdram_ba,
  output [12:0] sdram_a,
  inout [15:0] sdram_d,
  // GPDI (video) differential pairs
  output [3:0]  gpdi_dp, // {clock,R,G,B}
  output [3:0]  gpdi_dn,
  // GPIO
  output [27:0] gp,
  output [27:0] gn  
  );

wire [7:0]  __main_out_led;

wire        __main_out_sdram_clk;
wire        __main_out_sdram_cle;
wire        __main_out_sdram_dqm;
wire        __main_out_sdram_cs;
wire        __main_out_sdram_we;
wire        __main_out_sdram_cas;
wire        __main_out_sdram_ras;
wire [1:0]  __main_out_sdram_ba;
wire [12:0] __main_out_sdram_a;
  
wire [2:0]  __main_out_gpdi_dp;
wire [2:0]  __main_out_gpdi_dn;

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
  .clock(clk_25mhz),
  .reset(RST_q[0]),
  .out_led(__main_out_led),
  .inout_sdram_dq(sdram_d[7:0]),
  .out_sdram_clk(__main_out_sdram_clk),
  .out_sdram_cle(__main_out_sdram_cle),
  .out_sdram_dqm(__main_out_sdram_dqm),
  .out_sdram_cs(__main_out_sdram_cs),
  .out_sdram_we(__main_out_sdram_we),
  .out_sdram_cas(__main_out_sdram_cas),
  .out_sdram_ras(__main_out_sdram_ras),
  .out_sdram_ba(__main_out_sdram_ba),
  .out_sdram_a(__main_out_sdram_a),
  .out_gpdi_dp(__main_out_gpdi_dp),
  .out_gpdi_dn(__main_out_gpdi_dn),
  .in_btn(btn),
  .in_run(run_main)
);

always @* begin

  led          = __main_out_led;

  sdram_clk    = __main_out_sdram_clk;
  sdram_cke    = __main_out_sdram_cle;
  sdram_dqm[0] = __main_out_sdram_dqm;
  sdram_dqm[1] = 0;
  sdram_csn    = __main_out_sdram_cs;
  sdram_wen    = __main_out_sdram_we;
  sdram_casn   = __main_out_sdram_cas;
  sdram_rasn   = __main_out_sdram_ras;
  sdram_ba     = __main_out_sdram_ba;
  sdram_a      = __main_out_sdram_a;
  gpdi_dp[0+:3] = __main_out_gpdi_dp;
  gpdi_dn[0+:3] = __main_out_gpdi_dn;
  
end

OBCO dp(.I(clk_25mhz), .OT(gpdi_dp[3]), .OC(gpdi_dn[3]) );

assign sdram_d[15:8] = 0;

endmodule
