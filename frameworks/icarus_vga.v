`define ICARUS 1
$$ICARUS=1
$$VGA=1
$$SIMULATION =1
$$color_depth=6
$$color_max  =63
$$config['bram_wenable_width'] = 'data'
$$config['dualport_bram_wenable0_width'] = 'data'
$$config['dualport_bram_wenable1_width'] = 'data'

`timescale 1ns / 1ps

module top;

reg clk;
reg rst_n;

wire __main_video_clock;
wire __main_video_hs;
wire __main_video_vs;
wire [5:0] __main_video_r;
wire [5:0] __main_video_g;
wire [5:0] __main_video_b;

initial begin
  clk = 1'b0;
  rst_n = 1'b0;
  $display("icarus framework started");
  $dumpfile("icarus.fst");
  $dumpvars(0,top); // dump all (for full debugging)
  // $dumpvars(1,top); // dump only top (much faster and smaller)
  repeat(4) #5 clk = ~clk; 
  rst_n = 1'b1;
  forever #5 clk = ~clk;   // generates a 100 MHz clock
end

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
  .out_video_clock(__main_video_clock),
  .out_video_r(__main_video_r),
  .out_video_g(__main_video_g),
  .out_video_b(__main_video_b),
  .out_video_hs(__main_video_hs),
  .out_video_vs(__main_video_vs),  
  .in_run(run_main),
  .out_done(done_main)
);

always @* begin
  if (done_main && !RST_d[0]) $finish;
end

endmodule

