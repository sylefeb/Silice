// SL 2021-12-12
// produces an inverted clock of same frequency through DDR primitives
module ddr_clock(
        input  clock,
        input  enable,
        output reg ddr_clock
    );

reg renable;

`ifdef ICARUS
  always @(posedge clock) begin
    ddr_clock <= 0;
    renable   <= enable;
  end
  always @(negedge clock) begin
    ddr_clock <= renable;
  end
`endif

`ifdef ICEBREAKER
  always @(posedge clock) begin
    renable <= enable;
  end

  SB_IO #(
    .PIN_TYPE(6'b0100_11)
  ) sbio_clk (
      .PACKAGE_PIN(ddr_clock),
      .D_OUT_0(1'b0),
      .D_OUT_1(renable),
      .OUTPUT_CLK(clock)
  );
`endif

endmodule
