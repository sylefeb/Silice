module simul_spiflash(
  input CSn, 
	input CLK,
  inout IO0,
  inout IO1,
  inout IO2,
  inout IO3
);

W25Q128JVxIM simulator(
	.CLK(CLK),
  .CSn(CSn),
	.DIO(IO0),
	.DO (IO1),
	.WPn(IO2),
	.HOLDn(IO3)
);

endmodule
