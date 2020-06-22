`define ICESTICK 1
`default_nettype none
$$ICESTICK=1
$$HARDWARE=1

module top(
  input  CLK,
  output D1,
  output D2,
  output D3,
  output D4,
  output D5  
  );

wire __main_d1;
wire __main_d2;
wire __main_d3;
wire __main_d4;
wire __main_d5;

reg ready = 0;

reg [17:0] RST_d;
reg [17:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge CLK) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 18'b111111111111111111;
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
  .in_run(run_main)
);

assign D1 = __main_d1;
assign D2 = __main_d2;
assign D3 = __main_d3;
assign D4 = __main_d4;
assign D5 = __main_d5;

endmodule
