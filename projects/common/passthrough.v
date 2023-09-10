`ifndef PASSTHROUGH
`define PASSTHROUGH

module passthrough(
	input  inv,
  output outv);

assign outv = inv;

endmodule

`endif
