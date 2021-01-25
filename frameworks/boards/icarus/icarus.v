`define ICARUS 1
$$ICARUS      = 1
$$SIMULATION  = 1
$$NUM_LEDS    = 8
$$color_depth = 6
$$color_max   = 63
$$config['bram_wenable_width'] = 'data'
$$config['dualport_bram_wenable0_width'] = 'data'
$$config['dualport_bram_wenable1_width'] = 'data'

`timescale 1ns / 1ps

module top;

reg clk;
reg rst_n;

wire [7:0] __main_leds;

`ifdef VGA  
wire __main_video_clock;
wire __main_video_hs;
wire __main_video_vs;
wire [5:0] __main_video_r;
wire [5:0] __main_video_g;
wire [5:0] __main_video_b;
`endif

`ifdef UART
wire __main_uart_tx;
wire __main_uart_rx = 0;
`endif

`ifdef HDMI
wire [3:0] __main_out_gpdi_dp;
wire [3:0] __main_out_gpdi_dn;
`endif

`ifdef SDCARD
wire        __main_sd_clk;
wire        __main_sd_csn;
wire        __main_sd_mosi;
`endif

initial begin
  clk = 1'b0;
  rst_n = 1'b0;
  $display("icarus framework started");
  $dumpfile("icarus.fst");
`ifdef DUMP_TOP_ONLY
  $dumpvars(1,top); // dump only top (faster and smaller)
`else
  $dumpvars(0,top); // dump all (for full debugging)
`endif
`ifdef CLOCK_25MHz
  // generate a 25 MHz clock
  repeat(4) #20 clk = ~clk; 
  rst_n = 1'b1;
  forever #20 clk = ~clk;
`else
  // generate a 100 MHz clock
  repeat(4) #5 clk = ~clk; 
  rst_n = 1'b1;
  forever #5 clk = ~clk;   
`endif
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
  .out_leds(__main_leds),
`ifdef VGA  
  .out_video_clock(__main_video_clock),
  .out_video_r(__main_video_r),
  .out_video_g(__main_video_g),
  .out_video_b(__main_video_b),
  .out_video_hs(__main_video_hs),
  .out_video_vs(__main_video_vs),  
`endif  
`ifdef SDCARD
  .out_sd_csn    (__main_sd_csn),
  .out_sd_clk    (__main_sd_clk),
  .out_sd_mosi   (__main_sd_mosi),
  .in_sd_miso    (1'b0),
`endif  
`ifdef UART
  .out_uart_tx(__main_uart_tx),
  .in_uart_rx(__main_uart_rx),
`endif  
`ifdef HDMI
  .out_gpdi_dp  (__main_out_gpdi_dp),
  .out_gpdi_dn  (__main_out_gpdi_dn),
`endif  
  .in_run(run_main),
  .out_done(done_main)
);

always @* begin
  if (done_main && !RST_d[0]) $finish;
end

endmodule

