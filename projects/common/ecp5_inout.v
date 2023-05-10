module ecp5_inout(
  input  clock,
  input  oe,
  input  out,
  output in,
  inout  pin
);

  wire noe;
  wire i;
  wire o;
  // tristate pin
  BB       tripin(.I(o), .O(i), .B(pin), .T(noe));
  // output ff
  OFS1P3BX out_ff(.D(out), .Q(o),   .SCLK(clock), .PD(1'b0), .SP(1'b1));
  // output enable ff
  OFS1P3BX out_oe(.D(~oe), .Q(noe), .SCLK(clock), .PD(1'b0), .SP(1'b1));
  // input ddr
  IDDRX1F  ddrin (.D(i), .Q1(in), .SCLK(clock), .RST(1'b0));

endmodule
