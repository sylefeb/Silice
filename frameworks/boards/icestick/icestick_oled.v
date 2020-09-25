`define ICESTICK 1
`default_nettype none
$$ICESTICK=1
$$HARDWARE=1
$$OLED=1
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
  output BR3,
  output BR4,
  output BR5,
  output BR6,
  output BR7  
  );

wire __main_d1;
wire __main_d2;
wire __main_d3;
wire __main_d4;
wire __main_d5;

wire __main_oled_clk;
wire __main_oled_din;
wire __main_oled_cs;
wire __main_oled_rst;
wire __main_oled_dc;

// the init sequence pauses for some cycles
// waiting for BRAM init to stabalize
// this is a known issue with ice40 FPGAs
// https://github.com/YosysHQ/icestorm/issues/76

reg ready = 0;
reg [19:0] RST_d;
reg [19:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge CLK) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 20'b111111111111111111;
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
  .out_oled_din(__main_oled_din),
  .out_oled_clk(__main_oled_clk),
  .out_oled_cs(__main_oled_cs),
  .out_oled_dc(__main_oled_dc),
  .out_oled_rst(__main_oled_rst),
  .in_run(run_main)
);

assign D1  = __main_d1;
assign D2  = __main_d2;
assign D3  = __main_d3;
assign D4  = __main_d4;
assign D5  = __main_d5;
assign BR3 = __main_oled_din;
assign BR4 = __main_oled_clk;
assign BR5 = __main_oled_cs;
assign BR6 = __main_oled_dc;
assign BR7 = __main_oled_rst;

endmodule
