module pll(
	input  clock_in,
	output clock_out,
	output locked,
  output reset
	);

assign reset = ~locked;
wire   pll_clk_nobuf;

CC_PLL #(
		.REF_CLK("10"),    // reference input in MHz
		.OUT_CLK("25"),   // pll output frequency in MHz
    .LOCK_REQ(0),
		.PERF_MD("SPEED"), // LOWPOWER, ECONOMY, SPEED
		.LOW_JITTER(1),      // 0: disable, 1: enable low jitter mode
		.CI_FILTER_CONST(2), // optional CI filter constant
		.CP_FILTER_CONST(4)  // optional CP filter constant
	) pll_inst (
		.CLK_REF(clock_in), .CLK_FEEDBACK(1'b0), .USR_CLK_REF(1'b0),
		.USR_LOCKED_STDY_RST(1'b0), .USR_PLL_LOCKED_STDY(), .USR_PLL_LOCKED(locked),
		.CLK270(), .CLK180(), .CLK90(), .CLK0(pll_clk_nobuf), .CLK_REF_OUT()
	);

CC_BUFG pll_bufg (.I(pll_clk_nobuf), .O(clock_out));

endmodule
