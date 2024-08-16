/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// for tinytapeout we target ice40, but then replace SB_IO cells
// by a custom implementation
`define ICE40 1
$$ICE40=1
`define SIM_SB_IO 1
$$SIM_SB_IO=1

/**
 * PLL configuration
 *
 * This Verilog module was generated automatically
 * using the icepll tool from the IceStorm project.
 * Use at your own risk.
 *
 * Given input frequency:        12.000 MHz
 * Requested output frequency:   33.000 MHz
 * Achieved output frequency:    33.000 MHz
 */

module pll(
	input  clock_in,
	output clock_out,
	output locked
	);

SB_PLL40_CORE #(
		.FEEDBACK_PATH("SIMPLE"),
		.DIVR(4'b0000),		// DIVR =  0
		.DIVF(7'b1010111),	// DIVF = 87
		.DIVQ(3'b101),		// DIVQ =  5
		.FILTER_RANGE(3'b001)	// FILTER_RANGE = 1
	) uut (
		.LOCK(locked),
		.RESETB(1'b1),
		.BYPASS(1'b0),
		.REFERENCECLK(clock_in),
		.PLLOUTCORE(clock_out)
		);

endmodule

module top(
  output D1,
  output D2,
  output D3,
  output D4,
  output D5,
  output PMOD1,
  output PMOD10,
  inout  PMOD2,
  inout  PMOD3,
  output PMOD4,
  inout  PMOD7,
  inout  PMOD8,
  output PMOD9,
  output TR3,
  output TR4,
  output TR5,
  output TR6,
  output TR7,
  input  BR7,
  input  BR8,
  input  BR9,
  input  BR10,
  input  CLK
  );

reg ready = 0;
reg [23:0] RST_d;
reg [23:0] RST_q;

always @* begin
  RST_d = RST_q[23] ? RST_q : RST_q + 1;
end

always @(posedge CLK) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 0;
  end
end

wire run_main;
assign run_main = 1'b1;

wire uio_out0,uio_oe0;
wire uio_out1,uio_oe1;
wire uio_out2,uio_oe2;
wire uio_out3,uio_oe3;

assign PMOD2 = uio_oe0 ? uio_out0 : 1'bz;
assign PMOD3 = uio_oe1 ? uio_out1 : 1'bz;
assign PMOD7 = uio_oe2 ? uio_out2 : 1'bz;
assign PMOD8 = uio_oe3 ? uio_out3 : 1'bz;

wire fast_clock;
pll _pll(.clock_in(CLK),.clock_out(fast_clock));

M_main __main(
  .clock(fast_clock),
  .reset(~RST_q[23]),
  .out_leds({D5,D4,D3,D2,D1}),
  .out_ram_bank({PMOD10,PMOD9}),
  .out_ram_clk({PMOD4}),
  .out_ram_csn({PMOD1}),

  .inout_ram_io0_i(PMOD2),
  .inout_ram_io0_o(uio_out0),
  .inout_ram_io0_oe(uio_oe0),

  .inout_ram_io1_i(PMOD3),
  .inout_ram_io1_o(uio_out1),
  .inout_ram_io1_oe(uio_oe1),

  .inout_ram_io2_i(PMOD7),
  .inout_ram_io2_o(uio_out2),
  .inout_ram_io2_oe(uio_oe2),

  .inout_ram_io3_i(PMOD8),
  .inout_ram_io3_o(uio_out3),
  .inout_ram_io3_oe(uio_oe3),

  .in_btn_0(BR7),
  .in_btn_1(BR8),
  .in_btn_2(BR9),
  .in_btn_3(BR10),

  .out_spiscreen_clk({TR4}),
  .out_spiscreen_csn({TR5}),
  .out_spiscreen_dc({TR6}),
  .out_spiscreen_mosi({TR3}),
  .out_spiscreen_resn({TR7}),
  .in_run(run_main)
);

endmodule
