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

    M_main __main(
    .clock        (clk),
    .reset        (1'b0),
    .out_leds     (__main_leds),
    .in_run       (1'b1)
    );

    assign leds = __main_leds;

endmodule
