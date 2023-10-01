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

  SB_IO #(
    .PIN_TYPE(6'b1100_01)
  ) sbio_clk (
      .PACKAGE_PIN(ddr_clock),
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
