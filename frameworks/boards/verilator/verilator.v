/*

Copyright 2019, (C) Sylvain Lefebvre and contributors
List contributors with: git shortlog -n -s -- <filename>

MIT license

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

(header_2_M)

*/
`define VERILATOR         1
`define COLOR_DEPTH       6
`define SDRAM_WORD_WIDTH 16
`define SIMULATION        1

$$VERILATOR   = 1
$$NUM_LEDS    = 8
$$SIMULATION  = 1
$$color_depth = 6
$$color_max   = 63
$$config['__display_supported'] = 'yes'
$$config['__write_supported']   = 'yes'
$$config['__finish_supported']  = 'yes'

`timescale 1ns / 1ps
`default_nettype none

module top(
  // SDRAM
  output reg  sdram_clock,
  output reg  sdram_cle,
  output reg [1:0] sdram_dqm,
  output reg  sdram_cs,
  output reg  sdram_we,
  output reg  sdram_cas,
  output reg  sdram_ras,
  output reg [1:0]  sdram_ba,
  output reg [12:0] sdram_a,
  input      [15:0] sdram_dq_i,
  output reg [15:0] sdram_dq_o,
  output reg sdram_dq_en,
  // VGA
  output video_clock,
  output reg [`COLOR_DEPTH-1:0] video_r,
  output reg [`COLOR_DEPTH-1:0] video_g,
  output reg [`COLOR_DEPTH-1:0] video_b,
  output video_hs,
  output video_vs,
  output [5:0] sdram_word_width,
  output [4:0] video_color_depth,
  // PWM Audio
  output pwm_audio,
  // SPI screen
  output spiscreen_clk,
  output spiscreen_mosi,
  output spiscreen_dc,
  output spiscreen_csn,
  output spiscreen_resn,
  output [1:0] spiscreen_driver,
  output [9:0] spiscreen_width,
  output [9:0] spiscreen_height,
  // parallel screen
  output prlscreen_clk,
  output [7:0] prlscreen_d,
  output prlscreen_rs,
  output prlscreen_csn,
  output prlscreen_resn,
  output [1:0] prlscreen_driver,
  output [9:0] prlscreen_width,
  output [9:0] prlscreen_height,
  // basic
  output [7:0] leds,
  input        clk
  );

// this is used by the verilator framework
// -> to know the output color depth
assign video_color_depth = `COLOR_DEPTH;
// -> to know the sdram word width
assign sdram_word_width  = `SDRAM_WORD_WIDTH;

wire        __main_sdram_clock;
wire        __main_sdram_cle;
wire [1:0]  __main_sdram_dqm;
wire        __main_sdram_cs;
wire        __main_sdram_we;
wire        __main_sdram_cas;
wire        __main_sdram_ras;
wire [1:0]  __main_sdram_ba;
wire [12:0] __main_sdram_a;
wire [15:0] __main_sdram_dq_o;
wire        __main_sdram_dq_en;

wire                     __main_video_clock;
wire [`COLOR_DEPTH-1:0]  __main_video_r;
wire [`COLOR_DEPTH-1:0]  __main_video_g;
wire [`COLOR_DEPTH-1:0]  __main_video_b;
wire                     __main_video_hs;
wire                     __main_video_vs;

wire [7:0]  __main_leds;

// reset

reg ready = 0;
reg [7:0] RST_d = 8'b11111111;
reg [7:0] RST_q = 8'b11111111;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge clk) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 8'b11111111;
  end
end

// main

wire   run_main;
assign run_main = 1'b1;
wire done_main;

M_main __main(
  .clock(clk),
  .reset(RST_q[0]),
`ifdef BASIC
  .out_leds(__main_leds),
`endif
`ifdef SDRAM
  .out_sdram_clock(__main_sdram_clock),
  .out_sdram_cle(__main_sdram_cle),
  .out_sdram_dqm(__main_sdram_dqm),
  .out_sdram_cs(__main_sdram_cs),
  .out_sdram_we(__main_sdram_we),
  .out_sdram_cas(__main_sdram_cas),
  .out_sdram_ras(__main_sdram_ras),
  .out_sdram_ba(__main_sdram_ba),
  .out_sdram_a(__main_sdram_a),
  .in_sdram_dq_i(sdram_dq_i),
  .out_sdram_dq_o(__main_sdram_dq_o),
  .out_sdram_dq_en(__main_sdram_dq_en),
`endif
`ifdef VGA
  .out_video_clock(__main_video_clock),
  .out_video_r(__main_video_r),
  .out_video_g(__main_video_g),
  .out_video_b(__main_video_b),
  .out_video_hs(__main_video_hs),
  .out_video_vs(__main_video_vs),
`endif
`ifdef PWM_AUDIO
  .out_pwm_audio(pwm_audio),
`endif
`ifdef OLED
  .out_oled_clk(spiscreen_clk),
  .out_oled_mosi(spiscreen_mosi),
  .out_oled_dc(spiscreen_dc),
  .out_oled_csn(spiscreen_csn),
  .out_oled_resn(spiscreen_resn),
  .out_spiscreen_driver(spiscreen_driver),
  .out_spiscreen_width(spiscreen_width),
  .out_spiscreen_height(spiscreen_height),
`endif
`ifdef SPISCREEN
  .out_spiscreen_clk(spiscreen_clk),
  .out_spiscreen_mosi(spiscreen_mosi),
  .out_spiscreen_dc(spiscreen_dc),
  .out_spiscreen_csn(spiscreen_csn),
  .out_spiscreen_resn(spiscreen_resn),
  .out_spiscreen_driver(spiscreen_driver),
  .out_spiscreen_width(spiscreen_width),
  .out_spiscreen_height(spiscreen_height),
`endif
`ifdef PARALLEL_SCREEN
  .out_prlscreen_clk(prlscreen_clk),
  .out_prlscreen_d(prlscreen_d),
  .out_prlscreen_rs(prlscreen_rs),
  .out_prlscreen_csn(prlscreen_csn),
  .out_prlscreen_resn(prlscreen_resn),
  .out_prlscreen_driver(prlscreen_driver),
  .out_prlscreen_width(prlscreen_width),
  .out_prlscreen_height(prlscreen_height),
`endif
  .in_run(run_main),
  .out_done(done_main)
);

assign sdram_clock  = __main_sdram_clock;
assign sdram_cle    = __main_sdram_cle;
assign sdram_dqm    = __main_sdram_dqm;
assign sdram_cs     = __main_sdram_cs;
assign sdram_we     = __main_sdram_we;
assign sdram_cas    = __main_sdram_cas;
assign sdram_ras    = __main_sdram_ras;
assign sdram_ba     = __main_sdram_ba;
assign sdram_a      = __main_sdram_a;
assign sdram_dq_o   = __main_sdram_dq_o;
assign sdram_dq_en  = __main_sdram_dq_en;

assign video_clock = __main_video_clock;
assign video_r     = __main_video_r;
assign video_g     = __main_video_g;
assign video_b     = __main_video_b;
assign video_hs    = __main_video_hs;
assign video_vs    = __main_video_vs;

assign leds        = __main_leds;

always @* begin
  if (done_main && !RST_d[0]) $finish;
end

endmodule
