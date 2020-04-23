module icestick_clk_25(     
  input  clock_in,
  output clock_out,
  output lock
);

  SB_PLL40_CORE #(.FEEDBACK_PATH("SIMPLE"),
                  .PLLOUT_SELECT("GENCLK"),
                  .DIVR(4'b0001),
                  .DIVF(7'b1000010),
                  .DIVQ(3'b100),
                  .FILTER_RANGE(3'b001),
                 ) uut (
                         .REFERENCECLK(clock_in),
                         .PLLOUTCORE(clock_out),
                         .LOCK(lock),
                         .RESETB(1'b1),
                         .BYPASS(1'b0)
                        );

endmodule
