module sb_io_inout(
  input        clock,
	input        oe,
  input        out,
	output       in,
  inout        pin
  );

  SB_IO #(
    .PIN_TYPE(6'b1010_00)
    //                ^^ input, not registered
    //           ^^^^ output + enable, not registered
  ) sbio (
      .PACKAGE_PIN(pin),
			.OUTPUT_ENABLE(oe),
      .D_OUT_0(out),
			.D_IN_1(in),
      .OUTPUT_CLK(clock),
      .INPUT_CLK(clock)
  );

endmodule

// http://www.latticesemi.com/~/media/LatticeSemi/Documents/TechnicalBriefs/SBTICETechnologyLibrary201504.pdf
