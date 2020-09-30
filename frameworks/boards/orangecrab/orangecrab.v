`define ORANGECRAB 1
`default_nettype none
$$ORANGECRAB=1
$$HARDWARE=1
$$NUM_LEDS=3

module top(
  input  CLK, // 38.8 MHz
  // bare
  output [2:0] LED
  );

// input/output wires

wire [2:0]  __main_out_leds;

assign LED  = __main_out_leds;

// reset

reg ready = 0;

reg [15:0] RST_d;
reg [15:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge CLK) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 16'b1111111111111111;
  end
end

// main

wire   run_main;
assign run_main = 1'b1;

M_main __main(
  .clock         (CLK),
  .reset         (RST_q[0]),
  .in_run        (run_main),
  .out_leds      (__main_out_leds)
);

endmodule
