// SL 2023-03-24

`ifndef VERILATOR_RANDOM
`define VERILATOR_RANDOM

module verilator_random(
            input              clock,
            output reg [31:0]  rnd);

  always @(posedge clock) begin
    rnd <= $c32("get_random()");
  end

endmodule

`endif
