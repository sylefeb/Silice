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
    // 50MHz clock input
    input clk,
    // Input from reset button (active low)
    input rst_n,
    // cclk input from AVR, high when AVR is ready
    input cclk,
    // Outputs to the 8 onboard LEDs
    output reg [7:0]led,
    // AVR SPI connections
    output reg spi_miso,
    input spi_ss,
    input spi_mosi,
    input spi_sck,
    // AVR ADC channel select
    output reg[3:0] spi_channel,
    // Serial connections
    input avr_tx, // AVR Tx => FPGA Rx
    output reg avr_rx, // AVR Rx => FPGA Tx
    input avr_rx_busy // AVR Rx buffer full
    );

// produce clean reset
reg clean_reset;

wire [1-1:0] __reset_cond_out;
reset_conditioner __reset_cond (
  .rcclk(clk),
  .in(~rst_n),
  .out(__reset_cond_out)
);

wire [7:0] __main_out_led;
wire __main_spi_miso;
wire __main_out_avr_rx;
wire [3:0] __main_out_spi_channel;

wire run_main;
assign run_main = 1'b1;

M_main __main(
  .clock(clk),
  .reset(clean_reset),
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
  .out_led(__main_out_led)
);

always @* begin
  clean_reset = __reset_cond_out;
  spi_miso    = __main_spi_miso;
  avr_rx      = __main_out_avr_rx;
  spi_channel = __main_out_spi_channel;
  led         = __main_out_led;
end

endmodule
