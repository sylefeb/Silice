`define ICESTICK 1
`default_nettype none
$$ICESTICK=1
$$HARDWARE=1
$$VGA=1

module top(
  input  CLK,
  output D1,
  output D2,
  output D3,
  output D4,
  output D5,
  output PMOD1, // 0
  output PMOD2, // 1
  output PMOD3, // 2 
  output PMOD4, // 3
  output PMOD8, // 4
  output PMOD9, // 5
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
wire __main_out_vga_v1;
wire __main_out_vga_v2;
wire __main_out_vga_v3;
wire __main_out_vga_v4;
wire __main_out_vga_v5;

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
  .out_video_v0(__main_out_vga_v0),
  .out_video_v1(__main_out_vga_v1),
  .out_video_v2(__main_out_vga_v2),  
  .out_video_v3(__main_out_vga_v3),
  .out_video_v4(__main_out_vga_v4),
  .out_video_v5(__main_out_vga_v5),  
  .in_run(run_main)
);

assign D1 = __main_d1;
assign D2 = __main_d2;
assign D3 = __main_d3;
assign D4 = __main_d4;
assign D5 = __main_d5;

assign PMOD1  = __main_out_vga_v0;
assign PMOD2  = __main_out_vga_v1;
assign PMOD3  = __main_out_vga_v2;
assign PMOD4  = __main_out_vga_v3;
assign PMOD8  = __main_out_vga_v4;
assign PMOD9  = __main_out_vga_v5;
assign PMOD7  = __main_out_vga_hs;
assign PMOD10 = __main_out_vga_vs;

endmodule
