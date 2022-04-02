module ice40_half_quarter_clock(
	input  clock_in,
	output clock_h,
	output clock_q,
	);

reg [1:0] qh;

always @(posedge clock_in) begin
  qh <= qh + 1;
end

SB_GB gbq(
    .USER_SIGNAL_TO_GLOBAL_BUFFER(qh[1]),
		.GLOBAL_BUFFER_OUTPUT(clock_q)
);

SB_GB gbh(
    .USER_SIGNAL_TO_GLOBAL_BUFFER(qh[0]),
		.GLOBAL_BUFFER_OUTPUT(clock_h)
);

endmodule
