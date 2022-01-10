module sb_io_inout(
  input        clock,
	input        oe,
  input        out,
	output       in,
  output       pin
  );

  SB_IO #(
    .PIN_TYPE(6'b1101_01)
    //                ^^ input, not registered
    //           ^^^^ output + enable registered
  ) sbio (
      .PACKAGE_PIN(pin),
			.OUTPUT_ENABLE(oe),
      .D_OUT_0(out),
			.D_IN_0(in),
      .OUTPUT_CLK(clock)
  );

endmodule

// http://www.latticesemi.com/~/media/LatticeSemi/Documents/TechnicalBriefs/SBTICETechnologyLibrary201504.pdf
