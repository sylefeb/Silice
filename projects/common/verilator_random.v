// SL 2023-03-24

module verilator_random(
            input              clock,
            output reg [31:0]  rnd);

  always @(posedge clock) begin
    rnd <= $c32("get_random()");
  end

endmodule
