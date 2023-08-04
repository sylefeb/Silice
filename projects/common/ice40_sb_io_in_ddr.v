module sb_io_in_ddr(
  input  clock,
	output in,
  input  pin
  );

  SB_IO #(
    .PIN_TYPE(6'b0000_00)
  ) sbio (
      .PACKAGE_PIN(pin),
			.D_IN_0(in),
      .INPUT_CLK(clock)
  );

endmodule

// http://www.latticesemi.com/~/media/LatticeSemi/Documents/TechnicalBriefs/SBTICETechnologyLibrary201504.pdf
