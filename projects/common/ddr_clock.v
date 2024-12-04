// SL 2021-12-12
// produces an inverted clock of same frequency through DDR primitives

`ifndef DDR_CLOCK
`define DDR_CLOCK

module ddr_clock(
        input  clock,
        input  enable,
        output ddr_clock
    );

`ifdef ICE40

`ifdef SIM_SB_IO
  _SB_IO #(
`else
  SB_IO #(
`endif
    .PIN_TYPE(6'b1100_00)
  ) sbio_clk (
`ifdef SPLIT_INOUTS
      .PACKAGE_PIN_O(ddr_clock),
`else
      .PACKAGE_PIN(ddr_clock),
`endif
      .D_OUT_0(1'b0),
      .D_OUT_1(1'b1),
      .OUTPUT_ENABLE(enable),
      .OUTPUT_CLK(clock)
  );

`else

`ifdef ECP5

reg rnenable;

ODDRX1F oddr
      (
        .Q(ddr_clock),
        .D0(1'b0),
        .D1(1'b1),
        .SCLK(clock),
        .RST(~enable)
      );

always @(posedge clock) begin
  rnenable <= ~enable;
end

`else

  reg renable;
  reg rddr_clock;
  always @(posedge clock) begin
    rddr_clock <= 0;
    renable    <= enable;
  end
  always @(negedge clock) begin
    rddr_clock <= renable;
  end
  assign ddr_clock = rddr_clock;

`endif
`endif

endmodule

`endif
