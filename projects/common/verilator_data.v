// SL 2021-12-15

module verilator_data(
            input         clock,
            input  [31:0] addr,
            output reg [7:0]  data);

  always @(posedge clock) begin
    data <= $c32("data(",addr,")");
  end

endmodule
