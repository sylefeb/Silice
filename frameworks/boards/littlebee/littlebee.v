`define LITTLEBEE 1
`default_nettype none
$$LITTLEBEE=1
$$HARDWARE=1
$$NUM_LEDS=8
$$NUM_BTNS=1
$$config['bram_wenable_width'] = 'data'
$$config['dualport_bram_wenable0_width'] = 'data'
$$config['dualport_bram_wenable1_width'] = 'data'
$$config['simple_dualport_bram_wenable0_width'] = 'data'
$$config['simple_dualport_bram_wenable1_width'] = 'data'

module top(
  output [7:0] led,
`ifdef BUTTONS
  input [0:0]  rst,
`endif
  input        clk
  );

wire [7:0] __main_leds;

// clock from design is used in case
// it relies on a PLL: in such cases
// we cannot use the clock fed into
// the PLL here
wire design_clk;

reg ready = 0;
reg [31:0] RST_d;
reg [31:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge design_clk) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 32'b111111111111111111111111111111;
  end
end

wire run_main;
assign run_main = 1'b1;

M_main __main(
  .clock(clk),
  .out_clock(design_clk),
  .reset(RST_d[0]),
  .out_leds(__main_leds),
`ifdef BUTTONS
  .in_btns({rst}),
`endif
  .in_run(run_main)
);

assign led = __main_leds;

endmodule
