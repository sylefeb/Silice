module sb_io_ddr(
  input        clock,
  input        out_0,
  input        out_1,
  output       pin
  );

  SB_IO #(
    .PIN_TYPE(6'b0100_00)
    //                ^^ ignored (input)
    //           ^^^^ DDR output
  ) sbio (
      .PACKAGE_PIN(pin),
      .D_OUT_0(out_0),
      .D_OUT_1(out_1),
      .OUTPUT_CLK(clock)
  );

endmodule

// http://www.latticesemi.com/~/media/LatticeSemi/Documents/TechnicalBriefs/SBTICETechnologyLibrary201504.pdf
