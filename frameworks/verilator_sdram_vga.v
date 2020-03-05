$$VERILATOR=1
`define VERILATOR 1

`default_nettype none

module vga(
  input       clk,
  // SDRAM
  output reg  sdram_clock,
  output reg  sdram_cle,
  output reg  sdram_dqm,
  output reg  sdram_cs,
  output reg  sdram_we,
  output reg  sdram_cas,
  output reg  sdram_ras,
  output reg [1:0]  sdram_ba,
  output reg [12:0] sdram_a,
  input      [7:0]  sdram_dq_i,
  output reg [7:0]  sdram_dq_o,
  output reg  sdram_dq_en,
  // VGA
  output vga_clock,
  output reg [3:0] vga_r,
  output reg [3:0] vga_g,
  output reg [3:0] vga_b,
  output vga_hs,
  output vga_vs
  );

wire        __main_sdram_clock;
wire        __main_sdram_cle;
wire        __main_sdram_dqm;
wire        __main_sdram_cs;
wire        __main_sdram_we;
wire        __main_sdram_cas;
wire        __main_sdram_ras;
wire [1:0]  __main_sdram_ba;
wire [12:0] __main_sdram_a;
wire [7:0]  __main_sdram_dq_o;
wire        __main_sdram_dq_en;

wire        __main_vga_clock;
wire [3:0]  __main_vga_r;
wire [3:0]  __main_vga_g;
wire [3:0]  __main_vga_b;
wire        __main_vga_hs;
wire        __main_vga_vs;

reg ready = 0;
reg [3:0] RST_d;
reg [3:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge clk) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 4'b1111;
  end
end

wire   run_main;
assign run_main = 1'b1;

M_main __main(
  .clock(clk),
  .reset(RST_d[0]),
  .out_sdram_clock(__main_sdram_clock),
  .out_sdram_cle(__main_sdram_cle),
  .out_sdram_dqm(__main_sdram_dqm),
  .out_sdram_cs(__main_sdram_cs),
  .out_sdram_we(__main_sdram_we),
  .out_sdram_cas(__main_sdram_cas),
  .out_sdram_ras(__main_sdram_ras),
  .out_sdram_ba(__main_sdram_ba),
  .out_sdram_a(__main_sdram_a),
  .in_sdram_dq_i(sdram_dq_i),
  .out_sdram_dq_o(__main_sdram_dq_o),
  .out_sdram_dq_en(__main_sdram_dq_en),
  .out_vga_clock(__main_vga_clock),
  .out_vga_r(__main_vga_r),
  .out_vga_g(__main_vga_g),
  .out_vga_b(__main_vga_b),
  .out_vga_hs(__main_vga_hs),
  .out_vga_vs(__main_vga_vs),
  .in_run(run_main)
);

assign sdram_clock  = __main_sdram_clock;
assign sdram_cle    = __main_sdram_cle;
assign sdram_dqm    = __main_sdram_dqm;
assign sdram_cs     = __main_sdram_cs;
assign sdram_we     = __main_sdram_we;
assign sdram_cas    = __main_sdram_cas;
assign sdram_ras    = __main_sdram_ras;
assign sdram_ba     = __main_sdram_ba;
assign sdram_a      = __main_sdram_a;
assign sdram_dq_o   = __main_sdram_dq_o;
assign sdram_dq_en  = __main_sdram_dq_en;

assign vga_clock = __main_vga_clock;
assign vga_r     = __main_vga_r;
assign vga_g     = __main_vga_g;
assign vga_b     = __main_vga_b;
assign vga_hs    = __main_vga_hs;
assign vga_vs    = __main_vga_vs;

endmodule
