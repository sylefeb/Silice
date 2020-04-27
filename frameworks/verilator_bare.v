`define VERILATOR 1
$$VERILATOR=1
$$SIMULATION=1

`timescale 1ns / 1ps
`default_nettype none

module bare(
  input  clk
);

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
wire done_main;

M_main __main(
  .clock(clk),
  .reset(RST_d[0]),
  .in_run(run_main),
  .out_done(done_main)
);

always @* begin
  if (done_main && !RST_d[0]) $finish;
end

endmodule

