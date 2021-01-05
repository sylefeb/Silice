`define ECPIX5 1
$$ECPIX5   = 1
$$HARDWARE = 1
$$NUM_LEDS = 12
$$config['dualport_bram_supported'] = 'no'
`default_nettype none

module top(
  // basic
  output [11:0] leds,
`ifdef UART
  // uart
  output  uart_rx,
  input   uart_tx,
`endif
  input  clk100
  );

reg ready = 0;

reg [31:0] RST_d;
reg [31:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge clk100) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 32'b111111111111111111111111111111;
  end
end

wire [11:0] __main_leds;

wire run_main;
assign run_main = 1'b1;

M_main __main(
  .reset         (RST_q[0]),
  .in_run        (run_main),
  .out_leds      (__main_leds),
`ifdef UART
  .out_uart_tx  (uart_tx),
  .in_uart_rx   (uart_rx),
`endif  
  .clock         (clk100)
);

assign leds = ~__main_leds;

endmodule

