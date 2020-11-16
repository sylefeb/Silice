`define YOSYS 1
`default_nettype none
$$HARDWARE = 1
$$NUM_LEDS = 4

module top(
  // LED outputs
  output [3:0] leds,
  input        clk
);

    wire [7:0] __main_leds;

    reg reset = 1;

    always @(posedge clk) begin
      if (reset) begin
        reset <= 0;
      end
    end

    M_main __main(
    .clock        (clk),
    .reset        (reset),
    .out_leds     (__main_leds),
    .in_run       (~reset)
    );

    assign leds = __main_leds;

endmodule
