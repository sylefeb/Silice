// SL 2021-12-12
// produces an inverted clock of same frequency through DDR primitives
module ddr_clock(
        input  clock,
        input  enable,
`ifdef ICARUS
        output reg ddr_clock
`else
        output ddr_clock
`endif
    );

`ifdef ICARUS
  reg renable;
  always @(posedge clock) begin
    ddr_clock <= 0;
    renable   <= enable;
  end
  always @(negedge clock) begin
    ddr_clock <= renable;
  end
`endif

`ifdef ICE40
  SB_IO #(
    .PIN_TYPE(6'b1100_11)
  ) sbio_clk (
      .PACKAGE_PIN(ddr_clock),
      .D_OUT_0(1'b0),
      .D_OUT_1(1'b1),
      .OUTPUT_ENABLE(enable),
      .OUTPUT_CLK(clock)
  );
`endif

endmodule
