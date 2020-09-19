`define ICEBREAKER 1
`default_nettype none
$$ICEBREAKER=1
$$HARDWARE=1

module top(
  input  CLK,
  output LED1,
  output LED2,
  output LED3,
  output LED4,
  output LED5
  );

wire __main_d1;
wire __main_d2;
wire __main_d3;
wire __main_d4;
wire __main_d5;

reg ready = 0;
reg [31:0] RST_d;
reg [31:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge CLK) begin
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
  .reset(RST_d),
  .out_led0(__main_d1),
  .out_led1(__main_d2),
  .out_led2(__main_d3),
  .out_led3(__main_d4),
  .out_led4(__main_d5),
  .in_run(run_main)
);

assign LED1 = __main_d1;
assign LED2 = __main_d2;
assign LED3 = __main_d3;
assign LED4 = __main_d4;
assign LED5 = __main_d5;

endmodule
