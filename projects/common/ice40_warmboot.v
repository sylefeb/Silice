`ifndef ICE40_WARMBOOT
`define ICE40_WARMBOOT

module ice40_warmboot(
	input boot,
	input [1:0] slot
	);

SB_WARMBOOT wb(
    .BOOT(boot),
		.S0(slot[0]),
		.S1(slot[1])
);

endmodule

`endif
