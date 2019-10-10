`default_nettype none

module bare(
  input  clk,
  output reg[7:0] outv
  );

wire [7:0] __main_outv;

reg ready = 0;
reg [3:0] RST_d;
reg [3:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge clk) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 4'b1111;
  end
end

wire run_main;
assign run_main = 1'b1;

M_main __main(
  .clock(clk),
  .reset(RST_d[0]),
  .in_run(run_main),
  .out_outv(__main_outv),
);

assign outv  = __main_outv;

endmodule

