`define ULX3S 1
`default_nettype none
$$ULX3S=1
$$HARDWARE=1
$$OLED=1

module top(
  input  clk_25mhz,
  output reg [7:0] led,
  input      [6:0] btn,  
  output reg oled_clk,
  output reg oled_mosi,
  output reg oled_dc,
  output reg oled_resn,
  output reg oled_csn
  );

wire [7:0] __main_led;
wire __main_oled_clk;
wire __main_oled_mosi;
wire __main_oled_dc;
wire __main_oled_resn;
wire __main_oled_csn;

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
  .clock        (clk_25mhz),
  .reset        (RST_d),
  .out_led      (__main_led),
  .out_oled_clk (__main_oled_clk),
  .out_oled_mosi(__main_oled_mosi),
  .out_oled_dc  (__main_oled_dc),
  .out_oled_resn(__main_oled_resn),
  .out_oled_csn (__main_oled_csn),
  .in_btn       (btn),
  .in_run       (run_main)
);

assign led       = __main_led;
assign oled_clk  = __main_oled_clk;
assign oled_mosi = __main_oled_mosi;
assign oled_dc   = __main_oled_dc;
assign oled_resn = __main_oled_resn;
assign oled_csn  = __main_oled_csn;

endmodule
