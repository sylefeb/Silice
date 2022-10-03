module simul_spiflash(
  input CSn,
	input CLK,
  inout IO0,
  inout IO1,
  inout IO2,
  inout IO3
);

MX25R1635F simulator(
	.SCLK(CLK),
  .CS  (CSn),
	.SI  (IO0),
	.SO  (IO1),
	.WP  (IO2),
	.SIO3(IO3)
);

endmodule
