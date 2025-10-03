/**
 * PLL configuration
 *
 * Given input frequency:        40.000 MHz
 * Requested output frequency:   40.000 MHz
 * Achieved output frequency:    40.000 MHz
 */

module pll(
	input  clock_in,
	output clock_out,
  output reset
	);

  wire lock;
  assign reset = ~lock;

  SB_PLL40_PAD #(.FEEDBACK_PATH("SIMPLE"),
                  .PLLOUT_SELECT("GENCLK"),
// 40
                  .DIVR(4'b0000),
                  .DIVF(7'b0001111),
                  .DIVQ(3'b100),
                  .FILTER_RANGE(3'b011),
//
                  .DELAY_ADJUSTMENT_MODE_FEEDBACK("FIXED"),
                  .FDA_FEEDBACK(4'b0000),
                  .DELAY_ADJUSTMENT_MODE_RELATIVE("FIXED"),
                  .FDA_RELATIVE(4'b0000),
                  .SHIFTREG_DIV_MODE(2'b00),
                  .ENABLE_ICEGATE(1'b0)
                 ) uut (
                         .PACKAGEPIN(clock_in),
                         .PLLOUTCORE(clock_out),
                         .EXTFEEDBACK(),
                         .DYNAMICDELAY(),
                         .LATCHINPUTVALUE(),
                         .RESETB(1'b1),
                         .LOCK(lock),
                         .BYPASS(1'b0)
                        );

endmodule
