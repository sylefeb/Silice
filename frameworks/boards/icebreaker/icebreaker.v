`define ICEBREAKER 1
`default_nettype none
$$ICEBREAKER=1
$$HARDWARE=1
$$NUM_LEDS=5
$$NUM_BTNS=3
$$VGA=1
$$color_depth=6
$$color_max  =63
$$config['bram_wenable_width'] = 'data'
$$config['dualport_bram_wenable0_width'] = 'data'
$$config['dualport_bram_wenable1_width'] = 'data'

module top(
  output LED1,
  output LED2,
  output LED3,
  output LED4,
  output LED5,
`ifdef BUTTONS
  input BTN1,
  input BTN2,
  input BTN3,
`endif
`ifdef VGA
  output P1A1, // r0
  output P1A2, // r1
  output P1A3, // r2
  output P1A4, // r3
  
  output P1A7,   // b0
  output P1A8,   // b1
  output P1A9,   // b2
  output P1A10,  // b3
  
  output P1B1,  // g0
  output P1B2,  // g1
  output P1B3,  // g2
  output P1B4,  // g3
  
  output P1B7, // hs
  output P1B8,  // vs
`endif  
  input  CLK
  );

wire [4:0] __main_leds;

// clock from design is used in case
// it relies on a PLL: in such cases
// we cannot use the clock fed into
// the PLL here
wire design_clk;

`ifdef VGA
wire __main_out_vga_hs;
wire __main_out_vga_vs;
wire __main_out_vga_v0;
wire [5:0] __main_out_vga_r;
wire [5:0] __main_out_vga_g;
wire [5:0] __main_out_vga_b;
`endif  

reg ready = 0;
reg [31:0] RST_d;
reg [31:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge design_clk) begin
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
  .clock(CLK),
  .out_clock(design_clk),
  .reset(RST_d[0]),
  .out_leds(__main_leds),
`ifdef BUTTONS
  .in_btns({BTN3,BTN2,BTN1}),
`endif
`ifdef VGA
  .out_video_hs(__main_out_vga_hs),
  .out_video_vs(__main_out_vga_vs),
  .out_video_r(__main_out_vga_r),
  .out_video_g(__main_out_vga_g),
  .out_video_b(__main_out_vga_b),
`endif
  .in_run(run_main)
);

assign LED1 = __main_leds[0+:1];
assign LED2 = __main_leds[1+:1];
assign LED3 = __main_leds[2+:1];
assign LED4 = __main_leds[3+:1];
assign LED5 = __main_leds[4+:1];

`ifdef VGA
assign P1A1  = __main_out_vga_r[2+:1];
assign P1A2  = __main_out_vga_r[3+:1];
assign P1A3  = __main_out_vga_r[4+:1];
assign P1A4  = __main_out_vga_r[5+:1];

assign P1A7  = __main_out_vga_b[2+:1];
assign P1A8  = __main_out_vga_b[3+:1];
assign P1A9  = __main_out_vga_b[4+:1];
assign P1A10 = __main_out_vga_b[5+:1];

assign P1B1  = __main_out_vga_g[2+:1];
assign P1B2  = __main_out_vga_g[3+:1];
assign P1B3  = __main_out_vga_g[4+:1];
assign P1B4  = __main_out_vga_g[5+:1];

assign P1B7  = __main_out_vga_hs;
assign P1B8  = __main_out_vga_vs;
`endif

endmodule
