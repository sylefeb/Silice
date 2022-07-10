// @sylefeb DDR module, wrapper around vendor specific primitive
//
// see also https://github.com/lawrie/ulx3s_examples/blob/master/hdmi/fake_differential.v
// MIT license, see LICENSE_MIT in Silice repo root

module ddr(
        input        clock,
        input  [1:0] twice,
        output       out_pin
    );

`ifdef MOJO

ODDR2 #(
    .DDR_ALIGNMENT("C0"),
    .INIT(1'b0),
    .SRTYPE("ASYNC")
) mddr (
    .D0(twice[0]),
    .D1(twice[1]),
    .Q (out_pin),
    .C0(clock),
    .C1(~clock),
    .CE(1),
    .S(0),
    .R(0)
  );

`else

`ifdef ULX3S

ODDRX1F mddr
      (
        .D0(twice[0]),
        .D1(twice[1]),
        .Q(out_pin),
        .SCLK(clock),
        .RST(0)
      );

`else

`ifdef ICARUS

reg ddr_out;
assign out_pin = ddr_out;

always @(posedge clock) begin
  ddr_out <= twice[0];
end

always @(negedge clock) begin
  ddr_out <= twice[1];
end

`endif

`endif
`endif

endmodule
