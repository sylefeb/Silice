// SL 2021-12-12
// produces an inverted clock of same frequency through DDR primitives
module ddr_clock(
        input  clock,
        input  enable,
        output reg ddr_clock
    );

`ifdef ICARUS
  always @(posedge clock) begin
    ddr_clock <= 0;
  end
  always @(negedge clock) begin
    ddr_clock <= enable;
  end  
`endif

`ifdef ICEBREAKER
  SB_IO #(
    .PIN_TYPE(6'b0100_00)
    //                 ^^ ignored (input)
    //           ^^^^^ DDR output
  ) sbio (
      .PACKAGE_PIN(ddr_clock),
      .D_OUT_0(1'b0),
      .D_OUT_1(enable),
      .OUTPUT_CLK(clock)
  );
`endif

endmodule
