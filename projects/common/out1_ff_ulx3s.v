// TODO allow parameteric modules from Silice

module out1_ff_ulx3s(
  input   clock,
  output  pin,
  input   d
);

  OFS1P3BX out_ff(.D(d), .Q(pin), .SCLK(clock), .PD(1'b0), .SP(1'b0));

endmodule
