`default_nettype none

module vga(
  input  clk,
  output vga_clock,
  output reg [3:0] vga_r,
  output reg [3:0] vga_g,
  output reg [3:0] vga_b,
  output vga_hs,
  output vga_vs
  );

wire __main_vga_clock;
wire [3:0] __main_vga_r;
wire [3:0] __main_vga_g;
wire [3:0] __main_vga_b;
wire __main_vga_hs;
wire __main_vga_vs;

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

wire run_main;
assign run_main = 1'b1;

M_main __main(
  .clock(clk),
  .reset(RST_d[0]),
  .out_vga_clock(__main_vga_clock),
  .out_vga_r(__main_vga_r),
  .out_vga_g(__main_vga_g),
  .out_vga_b(__main_vga_b),
  .out_vga_hs(__main_vga_hs),
  .out_vga_vs(__main_vga_vs),
  .in_run(run_main)
);

assign vga_clock = __main_vga_clock;
assign vga_r     = __main_vga_r;
assign vga_g     = __main_vga_g;
assign vga_b     = __main_vga_b;
assign vga_hs    = __main_vga_hs;
assign vga_vs    = __main_vga_vs;

endmodule
