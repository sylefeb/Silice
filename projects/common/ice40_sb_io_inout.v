`ifndef ICE40_SB_IO_INOUT
`define ICE40_SB_IO_INOUT

`ifndef SPLIT_INOUTS

module sb_io_inout #(parameter TYPE=6'b1101_00) (
  input        clock,
	input        oe,
  input        out,
	output       in,
  inout        pin
  );

  wire unused;

`ifdef SIM_SB_IO
  _SB_IO #(
`else
  SB_IO #(
`endif
    .PIN_TYPE(TYPE)
  ) sbio (
      .PACKAGE_PIN(pin),
			.OUTPUT_ENABLE(oe),
      .D_OUT_0(out),
      .D_OUT_1(out),
      .D_IN_0(unused),
			.D_IN_1(in),
      .OUTPUT_CLK(clock),
      .INPUT_CLK(clock)
  );

endmodule

// http://www.latticesemi.com/~/media/LatticeSemi/Documents/TechnicalBriefs/SBTICETechnologyLibrary201504.pdf

`else

module sb_io_inout #(parameter TYPE=6'b1101_00) (
  input        clock,
	input        oe,
  input        out,
	output       in,
  input        pin_i,
  output       pin_o,
  output       pin_oe
  );

  wire unused;

`ifdef SIM_SB_IO
  _SB_IO #(
`else
  SB_IO #(
`endif
    .PIN_TYPE(TYPE)
  ) sbio (
      .PACKAGE_PIN_I(pin_i),
      .PACKAGE_PIN_O(pin_o),
      .PACKAGE_PIN_OE(pin_oe),
			.OUTPUT_ENABLE(oe),
      .D_OUT_0(out),
      .D_OUT_1(out),
      .D_IN_0(unused),
			.D_IN_1(in),
      .OUTPUT_CLK(clock),
      .INPUT_CLK(clock)
  );

endmodule

`endif

`endif
