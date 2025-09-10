`ifndef ICE40_SB_IO
`define ICE40_SB_IO

module sb_io(
  input        clock,
  input        out,
  output       pin
  );
`ifdef SIM_SB_IO
  _SB_IO #(
`else
  SB_IO #(
`endif
    .PIN_TYPE(6'b0101_01)
    //                ^^ ignored (input)
    //           ^^^^ registered output
  ) sbio (
`ifdef SPLIT_INOUTS
      .PACKAGE_PIN_O(pin),
`else
      .PACKAGE_PIN(pin),
`endif
      .D_OUT_0(out),
      .OUTPUT_ENABLE(1'b1),
      .OUTPUT_CLK(clock)
  );

endmodule

`endif

// http://www.latticesemi.com/~/media/LatticeSemi/Documents/TechnicalBriefs/SBTICETechnologyLibrary201504.pdf
