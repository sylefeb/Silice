`define CROSSLINKNX_EVN 1
$$CROSSLINKNX_EVN=1
$$HARDWARE=1
$$VGA=1
$$color_depth=6
$$color_max  =63
$$config['bram_wenable_width'] = 'data'
$$config['dualport_bram_wenable0_width'] = 'data'
$$config['dualport_bram_wenable1_width'] = 'data'

module top(
  input  CLK,
  output LED0,
  output LED1,
  output LED2,
  output LED3,
  output LED4,

  output PMOD0_1, // r0
  output PMOD0_2, // r1
  output PMOD0_3, // r2
  output PMOD0_4, // r3
  
  output PMOD0_7, // b0
  output PMOD0_8, // b1
  output PMOD0_9, // b2
  output PMOD0_10,// b3
  
  output PMOD1_1, // g0
  output PMOD1_2, // g1
  output PMOD1_3, // g2
  output PMOD1_4, // g3
  
  output PMOD1_7, // hs
  output PMOD1_8  // vs
  );

wire __main_d1;
wire __main_d2;
wire __main_d3;
wire __main_d4;
wire __main_d5;

wire __main_out_vga_hs;
wire __main_out_vga_vs;
wire __main_out_vga_v0;
wire [5:0] __main_out_vga_r;
wire [5:0] __main_out_vga_g;
wire [5:0] __main_out_vga_b;

BB u0_BB (.B(CLK),
	.I(1'b0),
	.T(1'b1),
	.O(clk_s)
);

reg ready = 0;
reg [31:0] RST_d;
reg [31:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge clk_s) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 32'b111111111111111111111111111111;
  end
end

wire run_main;
assign run_main = 1'b1;

M_main __main(
  .clock(clk_s),
  .reset(RST_d[0]),
  .out_led0(__main_d1),
  .out_led1(__main_d2),
  .out_led2(__main_d3),
  .out_led3(__main_d4),
  .out_led4(__main_d5),
  .out_video_hs(__main_out_vga_hs),
  .out_video_vs(__main_out_vga_vs),
  .out_video_r(__main_out_vga_r),
  .out_video_g(__main_out_vga_g),
  .out_video_b(__main_out_vga_b),
  .in_run(run_main)
);

assign LED0 = __main_d1;
assign LED1 = __main_d2;
assign LED2 = __main_d3;
assign LED3 = __main_d4;
assign LED4 = __main_d5;

assign PMOD0_1  = __main_out_vga_r[2+:1];
assign PMOD0_2  = __main_out_vga_r[3+:1];
assign PMOD0_3  = __main_out_vga_r[4+:1];
assign PMOD0_4  = __main_out_vga_r[5+:1];

assign PMOD0_7  = __main_out_vga_b[2+:1];
assign PMOD0_8  = __main_out_vga_b[3+:1];
assign PMOD0_9  = __main_out_vga_b[4+:1];
assign PMOD0_10 = __main_out_vga_b[5+:1];

assign PMOD1_1  = __main_out_vga_g[2+:1];
assign PMOD1_2  = __main_out_vga_g[3+:1];
assign PMOD1_3  = __main_out_vga_g[4+:1];
assign PMOD1_4  = __main_out_vga_g[5+:1];

assign PMOD1_7  = __main_out_vga_hs;
assign PMOD1_8  = __main_out_vga_vs;

endmodule
