module ice40_half_clock(
	input  clock_in,
	output clock_out
	);

reg half;

always @(posedge clock_in) begin
  half <= ~half;
end

(* BEL="X13/Y0/gb" *)
SB_GB gb( 
    .USER_SIGNAL_TO_GLOBAL_BUFFER(half),
		.GLOBAL_BUFFER_OUTPUT(clock_out)
);

endmodule
