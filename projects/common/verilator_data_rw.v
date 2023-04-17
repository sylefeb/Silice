// SL 2023-04-15

module verilator_data_rw(
            input            clock,
            input  [31:0]    addr,
            input            wenable,
            input  reg [7:0] wdata,
            output reg [7:0] rdata);

  always @(posedge clock) begin
    rdata <= $c32("data(",addr,")");
    $c("data_write(",wenable,",",addr,",",wdata,");");
  end

endmodule
