// @sylefeb DDR module, wrapper around vendor specific primitive
//
// see also https://github.com/lawrie/ulx3s_examples/blob/master/hdmi/fake_differential.v

module ddr(
        input        clock,
        input  [1:0] twice,
        output       out_pin
    );

`ifdef ULX3S

ODDRX1F ddr_pos
      (
        .D0(twice[0]),
        .D1(twice[1]),
        .Q(out_pin),
        .SCLK(clock),
        .RST(0)
      );

`else

`ifdef ICARUS

assign out_pin = twice[0];

`endif

`endif

endmodule
