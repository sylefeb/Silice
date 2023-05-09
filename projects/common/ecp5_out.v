
module ecp5_out(
  input   clock,
  output  pin,
  input   out
);

OFS1P3BX out_ff(.D(out), .Q(pin), .SCLK(clock), .PD(1'b0), .SP(1'b1));

endmodule
