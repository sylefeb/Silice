// TODO allow parameteric modules from Silice

module out2_ff_ulx3s(
  input        clock,
  output [1:0] pin,
  input  [1:0] d
);

  OFS1P3BX out_ff[1:0] (.D(d), .Q(pin), .SCLK(clock), .PD(1'b0), .SP(1'b0));

endmodule
