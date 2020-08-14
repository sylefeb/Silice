`define DE10NANO 1
$$DE10NANO=1
$$VGA=1
$$HARDWARE=1
$$color_depth=6
$$color_max  =63
$$SDRAM=1
$$OLED=1
$$if YOSYS then
$$config['bram_wenable_width'] = 'data'
$$config['dualport_bram_wenable0_width'] = 'data'
$$config['dualport_bram_wenable1_width'] = 'data'
$$end

module SdramVga(
    input clk,
    output reg[7:0] led,
    // SDRAM
    output reg SDRAM_CLK,
    output reg SDRAM_CKE,
    output reg SDRAM_DQML,
    output reg SDRAM_DQMH,
    output reg SDRAM_nCS,
    output reg SDRAM_nWE,
    output reg SDRAM_nCAS,
    output reg SDRAM_nRAS,
    output reg [1:0] SDRAM_BA,
    output reg [12:0] SDRAM_A,
    // inout [15:0] SDRAM_DQ,
    inout [7:0] SDRAM_DQ,
    // VGA
    output reg vga_hs,
    output reg vga_vs,
    output reg [5:0] vga_r,
    output reg [5:0] vga_g,
    output reg [5:0] vga_b,
    // keypad
    output reg [3:0] kpadC,
    input      [3:0] kpadR,
    // LCD
    output reg lcd_rs,
    output reg lcd_rw,
    output reg lcd_e,
    output reg [7:0] lcd_d,
    // OLED
    output reg oled_din,
    output reg oled_clk,
    output reg oled_cs,
    output reg oled_dc,
    output reg oled_rst
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

wire [3:0]  __main_out_kpadC;

wire        __main_out_lcd_rs;
wire        __main_out_lcd_rw;
wire        __main_out_lcd_e;
wire [7:0]  __main_out_lcd_d;

wire        __main_out_oled_din;
wire        __main_out_oled_clk;
wire        __main_out_oled_cs;
wire        __main_out_oled_dc;
wire        __main_out_oled_rst;


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
  .clock(clk),
  .reset(reset_main),
  .in_run(run_main),
  .inout_sdram_dq(SDRAM_DQ[7:0]),
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
  .out_video_hs(__main_out_vga_hs),
  .out_video_vs(__main_out_vga_vs),
  .out_video_r(__main_out_vga_r),
  .out_video_g(__main_out_vga_g),
  .out_video_b(__main_out_vga_b),
  .out_kpadC(__main_out_kpadC),
  .in_kpadR(kpadR[3:0]),
  .out_lcd_rs(__main_out_lcd_rs),
  .out_lcd_rw(__main_out_lcd_rw),
  .out_lcd_e(__main_out_lcd_e),
  .out_lcd_d(__main_out_lcd_d),
  .out_oled_din(__main_out_oled_din),
  .out_oled_clk(__main_out_oled_clk),
  .out_oled_cs(__main_out_oled_cs),
  .out_oled_dc(__main_out_oled_dc),
  .out_oled_rst(__main_out_oled_rst)
);

always @* begin

  led          = __main_out_led;

  SDRAM_CLK    = __main_out_sdram_clk;
  SDRAM_CKE    = __main_out_sdram_cle;
  SDRAM_DQML   = __main_out_sdram_dqm;
  SDRAM_DQMH   = 0;
  SDRAM_nCS    = __main_out_sdram_cs;
  SDRAM_nWE    = __main_out_sdram_we;
  SDRAM_nCAS   = __main_out_sdram_cas;
  SDRAM_nRAS   = __main_out_sdram_ras;
  SDRAM_BA     = __main_out_sdram_ba;
  SDRAM_A      = __main_out_sdram_a;
  vga_hs       = __main_out_vga_hs;
  vga_vs       = __main_out_vga_vs;
  vga_r        = __main_out_vga_r;
  vga_g        = __main_out_vga_g;
  vga_b        = __main_out_vga_b;
  kpadC        = __main_out_kpadC;
  lcd_rs       = __main_out_lcd_rs;
  lcd_rw       = __main_out_lcd_rw;
  lcd_e        = __main_out_lcd_e;
  lcd_d        = __main_out_lcd_d;
  oled_din     = __main_out_oled_din;
  oled_clk     = __main_out_oled_clk;
  oled_cs      = __main_out_oled_cs;
  oled_dc      = __main_out_oled_dc;
  oled_rst     = __main_out_oled_rst;
  
end

endmodule
