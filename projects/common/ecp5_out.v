
module ecp5_out(
  input   clock,
  output  pin,
  input   out
);
/*
  reg rout;
  always @(posedge clock) begin
    rout <= out;
  end
  assign pin = rout;
*/

//OFS1P3BX out_ff(.D(out), .Q(pin), .SCLK(clock), .PD(1'b0), .SP(1'b0));

ODDRX1F oddr
      (
        .Q(pin),
        .D0(out),
        .D1(out),
        .SCLK(clock),
        .RST(1'b0)
      );

endmodule
