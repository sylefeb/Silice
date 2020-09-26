`define ULX3S 1
`default_nettype none
$$ULX3S    = 1
$$HARDWARE = 1
$$OLED     = 1
$$SDCARD   = 1

module top(
  input   clk_25mhz,
  output  [7:0] led,
  input   [6:0] btn,  
  // oled
  output  oled_clk,
  output  oled_mosi,
  output  oled_dc,
  output  oled_resn,
  output  oled_csn,
  // sdcard
  output  sd_clk,
  output  sd_csn,
  output  sd_mosi,
  input   sd_miso
  );

wire [7:0] __main_led;

wire __main_oled_clk;
wire __main_oled_mosi;
wire __main_oled_dc;
wire __main_oled_resn;
wire __main_oled_csn;

wire __main_sd_clk;
wire __main_sd_csn;
wire __main_sd_mosi;

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
  .reset        (RST_q[0]),
  .out_led      (__main_led),
  .out_oled_clk (__main_oled_clk),
  .out_oled_mosi(__main_oled_mosi),
  .out_oled_dc  (__main_oled_dc),
  .out_oled_resn(__main_oled_resn),
  .out_oled_csn (__main_oled_csn),
  .out_sd_csn   (__main_sd_csn),
  .out_sd_clk   (__main_sd_clk),
  .out_sd_mosi  (__main_sd_mosi),
  .in_sd_miso   (sd_miso),
  .in_btn       (btn),
  .in_run       (run_main)
);

assign led       = __main_led;

assign oled_clk  = __main_oled_clk;
assign oled_mosi = __main_oled_mosi;
assign oled_dc   = __main_oled_dc;
assign oled_resn = __main_oled_resn;
assign oled_csn  = __main_oled_csn;

assign sd_clk    = __main_sd_clk;
assign sd_csn    = __main_sd_csn;
assign sd_mosi   = __main_sd_mosi;

endmodule
