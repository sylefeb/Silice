`define ULX3S 1
`default_nettype none
$$ULX3S=1
$$HARDWARE=1

module top(
  input  clk_25mhz,
  output reg [7:0] led
  );

wire [7:0] __main_led;

reg ready = 0;

reg [31:0] RST_d;
reg [31:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge clk_25mhz) begin
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
  .clock(clk_25mhz),
  .reset(RST_d),
  .out_led(__main_led),
  .in_run(run_main)
);

assign led = __main_led;

endmodule
