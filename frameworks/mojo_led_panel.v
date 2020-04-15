`define MOJO 1
$$MOJO=1
$$HARDWARE=1

module reset_conditioner (
    input rcclk,
    input in,
    output reg out
  );  
  localparam STAGES = 3'h4;  
  reg [3:0] M_stage_d, M_stage_q = 4'hf;  
  always @* begin
    M_stage_d = M_stage_q;
    
    M_stage_d = {M_stage_q[0+2-:3], 1'h0};
    out = M_stage_q[3+0-:1];
  end  
  always @(posedge rcclk) begin
    if (in == 1'b1) begin
      M_stage_q <= 4'hf;
    end else begin
      M_stage_q <= M_stage_d;
    end
  end 
endmodule

module mojo_top(
    input clk,
    input rst_n,
    input cclk,
    output reg[7:0] led,
    output reg spi_miso,
    input spi_ss,
    input spi_mosi,
    input spi_sck,
    output reg[3:0] spi_channel,
    input avr_tx,
    output reg avr_rx,
    input avr_rx_busy,
	output speaker,
	input mic_data,
	output mic_clk,
	output rtc_sclk,
	output rtc_cs,
	output rtc_mosi,
	input rtc_miso,
	input rtc_32khz,
	input rtc_int,
	input up_button,
	input down_button,
	input select_button,
	output reg[7:0]d1_c,
	output reg[7:0]d1_r,
	output reg[7:0]d1_g,
	output reg[7:0]d1_b,
	output reg[7:0]d2_c,
	output reg[7:0]d2_r,
	output reg[7:0]d2_g,
	output reg[7:0]d2_b
    );

assign speaker = 1'b0;

// these signals should be high-z when not used
assign mic_clk = 1'bz;
assign rtc_sclk = 1'bz;
assign rtc_cs = 1'bz;
assign rtc_mosi = 1'bz;

// produce clean reset
reg reset;

wire [1-1:0] __reset_cond_out;
reset_conditioner __reset_cond (
  .rcclk(clk),
  .in(~rst_n),
  .out(__reset_cond_out)
);

wire [7:0] __main_out_led;
wire [7:0] __main_out_d1_c;
wire [7:0] __main_out_d1_r;
wire [7:0] __main_out_d1_g;
wire [7:0] __main_out_d1_b;
wire [7:0] __main_out_d2_c;
wire [7:0] __main_out_d2_r;
wire [7:0] __main_out_d2_g;
wire [7:0] __main_out_d2_b;
wire __main_spi_miso;
wire __main_out_avr_rx;
wire [3:0] __main_out_spi_channel;

wire run_main;
assign run_main = 1'b1;

M_main __main(
  .clock(clk),
  .reset(reset),
  .in_run(run_main),
  .in_cclk(cclk),
  .in_spi_ss(spi_ss),
  .in_spi_sck(spi_sck),
  .in_avr_tx(avr_tx),
  .in_avr_rx_busy(avr_rx_busy),
  .in_spi_mosi(spi_mosi),
  .out_spi_miso(__main_spi_miso),
  .out_avr_rx(__main_out_avr_rx),
  .out_spi_channel(__main_out_spi_channel),
  .out_led(__main_out_led),
  .out_d1_c(__main_out_d1_c),
  .out_d1_r(__main_out_d1_r),
  .out_d1_g(__main_out_d1_g),
  .out_d1_b(__main_out_d1_b),
  .out_d2_c(__main_out_d2_c),
  .out_d2_r(__main_out_d2_r),
  .out_d2_g(__main_out_d2_g),
  .out_d2_b(__main_out_d2_b)
);

always @* begin
  reset        = __reset_cond_out;  
  spi_miso     = __main_spi_miso;
  avr_rx       = __main_out_avr_rx;
  spi_channel  = __main_out_spi_channel;
  
  led   = __main_out_led;
  d1_c  = __main_out_d1_c;
  d1_r  = __main_out_d1_r;
  d1_g  = __main_out_d1_g;
  d1_b  = __main_out_d1_b;
  d2_c  = __main_out_d2_c;
  d2_r  = __main_out_d2_r;
  d2_g  = __main_out_d2_g;
  d2_b  = __main_out_d2_b;
  
end

endmodule
