module pll(
  input  clock_in,
  output clock_out,
  output rst
);
  wire lock;
  assign rst = ~lock;
  SB_PLL40_CORE #(.FEEDBACK_PATH("SIMPLE"),
                  .PLLOUT_SELECT("GENCLK"),
                  .DIVR(4'b0000),
                  .DIVF(7'b1001111),
                  .DIVQ(3'b011),
                  .FILTER_RANGE(3'b001),
                 ) uut (
                         .REFERENCECLK(clock_in),
                         .PLLOUTCORE(clock_out),
                         .RESETB(1'b1),
                         .BYPASS(1'b0),
                         .LOCK(lock)
                        );

endmodule
