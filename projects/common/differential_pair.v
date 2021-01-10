// @sylefeb differential pair for HDMI, outputting dual rate
//
// see also https://github.com/lawrie/ulx3s_examples/blob/master/hdmi/fake_differential.v

module differential_pair(
        input   clock,
        input   [1:0] pos,
        input   [1:0] neg,
        output  out_pin_pos,
        output  out_pin_neg
    );

`ifdef ULX3S

ODDRX1F ddr_pos
      (
        .D0(pos[0]),
        .D1(pos[1]),
        .Q(out_pin_pos),
        .SCLK(clock),
        .RST(0)
      );

ODDRX1F ddr_neg
      (
        .D0(neg[0]),
        .D1(neg[1]),
        .Q(out_pin_neg),
        .SCLK(clock),
        .RST(0)
      );

`else

`ifdef ICARUS

assign out_pin_pos = pos[0];
assign out_pin_neg = neg[0];

`endif

`endif

endmodule
