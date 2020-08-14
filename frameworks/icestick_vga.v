`define ICESTICK 1
`default_nettype none
$$ICESTICK=1
$$HARDWARE=1
$$VGA=1
$$color_depth=6
$$color_max  =63
$$config['bram_wenable_width'] = 'data'
$$config['dualport_bram_wenable0_width'] = 'data'
$$config['dualport_bram_wenable1_width'] = 'data'

module top(
  input  CLK,
  output D1,
  output D2,
  output D3,
  output D4,
  output D5,

  output PMOD1, // r0
  output PMOD2, // r1
  output PMOD3, // r2 
  output PMOD4, // r3
  output PMOD8, // r4
  output PMOD9, // r5
  
  output TR10, // g0
  output TR9,  // g1
  output TR8,  // g2 
  output TR7,  // g3
  output TR6,  // g4
  output TR5,  // g5
  
  output BR10, // b0
  output BR9,  // b1
  output BR8,  // b2 
  output BR7,  // b3
  output BR6,  // b4
  output BR5,  // b5

  output PMOD7, // hs
  output PMOD10 // vs
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

reg ready = 0;
reg [3:0] RST_d;
reg [3:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge CLK) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 4'b1111;
  end
end

wire run_main;
assign run_main = 1'b1;

M_main __main(
  .clock(CLK),
  .reset(RST_d),
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

assign D1 = __main_d1;
assign D2 = __main_d2;
assign D3 = __main_d3;
assign D4 = __main_d4;
assign D5 = __main_d5;

assign PMOD1  = __main_out_vga_r[5+:1];
assign PMOD2  = __main_out_vga_r[4+:1];
assign PMOD3  = __main_out_vga_r[3+:1];
assign PMOD4  = __main_out_vga_r[2+:1];
assign PMOD8  = __main_out_vga_r[1+:1];
assign PMOD9  = __main_out_vga_r[0+:1];

assign TR10   = __main_out_vga_g[5+:1];
assign TR9    = __main_out_vga_g[4+:1];
assign TR8    = __main_out_vga_g[3+:1];
assign TR7    = __main_out_vga_g[2+:1];
assign TR6    = __main_out_vga_g[1+:1];
assign TR5    = __main_out_vga_g[0+:1];

assign BR10   = __main_out_vga_b[5+:1];
assign BR9    = __main_out_vga_b[4+:1];
assign BR8    = __main_out_vga_b[3+:1];
assign BR7    = __main_out_vga_b[2+:1];
assign BR6    = __main_out_vga_b[1+:1];
assign BR5    = __main_out_vga_b[0+:1];

assign PMOD7  = __main_out_vga_hs;
assign PMOD10 = __main_out_vga_vs;

endmodule
