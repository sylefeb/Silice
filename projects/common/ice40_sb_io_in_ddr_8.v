`ifndef ICE40_SB_IO_IN_DDR_8
`define ICE40_SB_IO_IN_DDR_8

module sb_io_in_ddr_8(
  input        clock,
	output [7:0] in,
  input  [7:0] pin
  );

  SB_IO #(
    .PIN_TYPE(6'b0000_00)
  ) sbio[7:0] (
      .PACKAGE_PIN(pin),
			.D_IN_0(in),
      .INPUT_CLK(clock)
  );

endmodule

`endif

// http://www.latticesemi.com/~/media/LatticeSemi/Documents/TechnicalBriefs/SBTICETechnologyLibrary201504.pdf
