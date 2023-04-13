// SL 2021-12-12
// produces an inverted clock of same frequency through DDR primitives
module ddr_clock(
        input  clock,
        input  enable,
        output ddr_clock
    );

`ifdef ICARUS
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
