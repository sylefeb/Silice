// NOTE: this is a modified exerpt from Yosys ice40 cell_sim.v
// WARNING: heavily hacked and does not support some cases (unregistered output, inverted output)

`timescale 1ps / 1ps
// `define SB_DFF_INIT initial Q = 0;
// `define SB_DFF_INIT

// SiliconBlue IO Cells

module _SB_IO (
	inout  PACKAGE_PIN,
	//input  LATCH_INPUT_VALUE,
	//input  CLOCK_ENABLE,
	input  INPUT_CLK,
	input  OUTPUT_CLK,
	input  OUTPUT_ENABLE,
	input  D_OUT_0,
	input  D_OUT_1,
	output D_IN_0,
	output D_IN_1
);
	parameter [5:0] PIN_TYPE = 6'b000000;
	parameter [0:0] PULLUP = 1'b0;
	parameter [0:0] NEG_TRIGGER = 1'b0;
	parameter IO_STANDARD = "SB_LVCMOS";

	reg dout, din_0, din_1;
	reg din_q_0, din_q_1;
	reg dout_q_0, dout_q_1;
	reg outena_q;

  wire CLOCK_ENABLE;
  assign CLOCK_ENABLE = 1'b1;
  wire LATCH_INPUT_VALUE;
  assign LATCH_INPUT_VALUE = 1'b0;

	// IO tile generates a constant 1'b1 internally if global_cen is not connected

	generate if (!NEG_TRIGGER) begin
		always @(posedge INPUT_CLK)  din_q_0         <= PACKAGE_PIN;
		always @(negedge INPUT_CLK)  din_q_1         <= PACKAGE_PIN;
		always @(posedge OUTPUT_CLK) dout_q_0        <= D_OUT_0;
		always @(negedge OUTPUT_CLK) dout_q_1        <= D_OUT_1;
		always @(posedge OUTPUT_CLK) outena_q        <= OUTPUT_ENABLE;
	end else begin
		always @(negedge INPUT_CLK)  din_q_0         <= PACKAGE_PIN;
		always @(posedge INPUT_CLK)  din_q_1         <= PACKAGE_PIN;
		always @(negedge OUTPUT_CLK) dout_q_0        <= D_OUT_0;
		always @(posedge OUTPUT_CLK) dout_q_1        <= D_OUT_1;
		always @(negedge OUTPUT_CLK) outena_q        <= OUTPUT_ENABLE;
	end endgenerate

	always @* begin
		//if (!PIN_TYPE[1] || !LATCH_INPUT_VALUE)
	  din_0 = PIN_TYPE[0] ? PACKAGE_PIN : din_q_0;
		din_1 = din_q_1;
	end

	// work around simulation glitches on dout in DDR mode
	//reg outclk_delayed_1;
	//reg outclk_delayed_2;
	//always @* outclk_delayed_1 <= OUTPUT_CLK;
	//always @* outclk_delayed_2 <= outclk_delayed_1;

	always @* begin
		//if (PIN_TYPE[3])
	  //  dout = PIN_TYPE[2] ? !dout_q_0 : D_OUT_0;
		//else
		dout = (/*outclk_delayed_2*/OUTPUT_CLK ^ NEG_TRIGGER) || PIN_TYPE[2] ? dout_q_0 : dout_q_1;
	end

	assign D_IN_0 = din_0, D_IN_1 = din_1;

	generate
		if (PIN_TYPE[5:4] == 2'b01) assign PACKAGE_PIN = dout;
		if (PIN_TYPE[5:4] == 2'b10) assign PACKAGE_PIN = OUTPUT_ENABLE ? dout : 1'bz;
		if (PIN_TYPE[5:4] == 2'b11) assign PACKAGE_PIN = outena_q ? dout : 1'bz;
	endgenerate

endmodule
