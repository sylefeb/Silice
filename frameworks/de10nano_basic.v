`define DE10NANO 1
$$DE10NANO=1
$$HARDWARE=1

module Basic(
    // 50MHz clock input
    input clk,
    // Outputs to the 8 onboard LEDs
    output reg LED0,
    output reg LED1,
    output reg LED2,
    output reg LED3,
    output reg LED4,
    output reg LED5,
    output reg LED6,
    output reg LED7
    );

wire [7:0] __main_out_led;

wire reset_main;
assign reset_main = 1'b0;
wire run_main;
assign run_main = 1'b1;

M_main __main(
  .clock(clk),
  .reset(reset_main),
  .in_run(run_main),
  .out_led(__main_out_led)
);

always @* begin
  LED0 = __main_out_led[0+:1];
  LED1 = __main_out_led[1+:1];
  LED2 = __main_out_led[2+:1];
  LED3 = __main_out_led[3+:1];
  LED4 = __main_out_led[4+:1];
  LED5 = __main_out_led[5+:1];
  LED6 = __main_out_led[6+:1];
  LED7 = __main_out_led[7+:1];
end

endmodule
