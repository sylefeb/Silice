`define ULX3S 1
`default_nettype none
$$ULX3S=1
$$HARDWARE=1
$$VGA=1
$$color_depth=6
$$color_max  =63
$$SDRAM=1

module top(
  input  clk_25mhz,
  output reg [7:0] led,
  input      [6:0] btn,
  // SDRAM
  output reg sdram_clk,
  output reg sdram_cke,
  output reg [1:0] sdram_dqm,
  output reg sdram_csn,
  output reg sdram_wen,
  output reg sdram_casn,
  output reg sdram_rasn,
  output reg [1:0] sdram_ba,
  output reg [12:0] sdram_a,
  inout [15:0] sdram_d,
  // GPIO
  output reg [27:0] gp,
  output reg [27:0] gn
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
  
wire        __main_out_vga_hs;
wire        __main_out_vga_vs;
wire [5:0]  __main_out_vga_r;
wire [5:0]  __main_out_vga_g;
wire [5:0]  __main_out_vga_b;

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
  .reset(RST_d),
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
  .out_video_hs(__main_out_vga_hs),
  .out_video_vs(__main_out_vga_vs),
  .out_video_r(__main_out_vga_r),
  .out_video_g(__main_out_vga_g),
  .out_video_b(__main_out_vga_b),
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
  gp[0]        = __main_out_vga_vs;
  gp[1]        = __main_out_vga_hs;
  gp[2]        = __main_out_vga_r[5];
  gp[3]        = __main_out_vga_r[4];
  gp[4]        = __main_out_vga_r[3];
  gp[5]        = __main_out_vga_r[2];
  gp[6]        = __main_out_vga_r[1];
  gp[7]        = __main_out_vga_r[0];
  gp[8]        = __main_out_vga_g[5];
  gp[9]        = __main_out_vga_g[4];
  gp[10]       = __main_out_vga_g[3];
  gp[11]       = __main_out_vga_g[2];
  gp[12]       = __main_out_vga_g[1];
  gp[13]       = __main_out_vga_g[0];
  gp[14]       = __main_out_vga_b[0];
  gp[15]       = __main_out_vga_b[1];
  gp[16]       = __main_out_vga_b[2];
  gp[17]       = __main_out_vga_b[3];
  gp[18]       = __main_out_vga_b[4];
  gp[19]       = __main_out_vga_b[5];
  
end

assign sdram_d[15:8] = 0;

endmodule
