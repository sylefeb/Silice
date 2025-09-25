`ifndef ICE40_SB_IO_DDR
`define ICE40_SB_IO_DDR

module sb_io_ddr(
  input        clock,
  input        out_0,
  input        out_1,
  output       pin
  );

`ifdef SIM_SB_IO
  _SB_IO #(
`else
  SB_IO #(
`endif
    .PIN_TYPE(6'b0100_01)
    //                ^^ ignored (input)
    //           ^^^^ DDR output
  ) sbio (
      .PACKAGE_PIN(pin),
      .D_OUT_0(out_0),
      .D_OUT_1(out_1),
      .OUTPUT_ENABLE(1'b1),
      .OUTPUT_CLK(clock)
  );

endmodule

`endif

// http://www.latticesemi.com/~/media/LatticeSemi/Documents/TechnicalBriefs/SBTICETechnologyLibrary201504.pdf
