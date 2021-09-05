`include "sdram_controller.v"
`include "../common/plls/ulx3s_50_25_100_100ph180.v"

module top(
  // basic
  output [7:0] leds,
  // buttons
  input  [6:0] btns,
  // sdram
  output sdram_clk,
  output sdram_cke,
  output [1:0]  sdram_dqm,
  output sdram_csn,
  output sdram_wen,
  output sdram_casn,
  output sdram_rasn,
  output [1:0]  sdram_ba,
  output [12:0] sdram_a,
  inout  [15:0] sdram_d,
  input  clk_25mhz
  );

// PLL 
// design runs at 100MHz
// SDRAM  runs at 100MHz with 180 degree phase shift
wire unused0;
wire unused1;
wire clk_design;
wire clk_sdram;
wire locked;
pll_50_25_100_100ph180 clk_gen (
  .clkin(clock),
  .clkout0(unused0),
  .clkout1(unused1),
  .clkout2(clk_design),
  .clkout3(clk_sdram),
  .locked (locked),
);
assign sdram_clk = clk_sdram;

// SDRAM interface
reg [25:0]  sd_addr = 0;
reg         sd_rw;
reg [15:0]  sd_data_in;
reg         sd_in_valid;
wire        sd_wmask = 1'b0; // ignored by this controller
wire        sd_done;
wire [15:0] sd_data_out;

// instantiates SDRAM controller
M_sdram_controller_autoprecharge_r16_w16 sdram_controller(
  .in_sd_addr     (sd_addr),
  .in_sd_rw       (sd_rw),
  .in_sd_data_in  (sd_data_in),
  .in_sd_in_valid (sd_in_valid),
  .in_sd_wmask    (sd_wmask), 
  .out_sd_done    (sd_done),
  .out_sd_data_out(sd_data_out),
  .out_sdram_cle  (sdram_cke),
  .out_sdram_dqm  (sdram_dqm),
  .out_sdram_cs   (sdram_csn),
  .out_sdram_we   (sdram_wen),
  .out_sdram_cas  (sdram_casn),
  .out_sdram_ras  (sdram_rasn),
  .out_sdram_ba   (sdram_ba),
  .out_sdram_a    (sdram_a),
  .inout_sdram_dq (sdram_d),
  .clock          (clk_design),
  .reset          (reset),
  .in_run         (1'b1)
);

// generates a reset signal for the design
reg [15:0] reset = 16'b111111111111111;
always @(posedge clk_design) begin
  reset <= reset >> 1;
end

// this test value will be
// 1) written to SDRAM
// 2) read back and displayed on LEDs
`define TEST_VALUE 16'b0000000010101010

reg [1:0] state = 0;
always @(posedge clk_design) begin
  // leds always display SDRAM controller output
  leds        <= sd_data_out;
  // state is updated as follows:
  // - during reset, state == 0
  // - state == 0, write TEST_VALUE to SDRAM @addr = 0
  // - state == 0 & sd_done, increment to 1
  // - state == 1, read from SDRAM @addr = 0
  // - state == 1 & sd_done, increment to 2
  // - state == 2, stay there 
  state       <= reset ? 0 : (state != 2 ? 
                             (sd_done ? state + 1 : state) 
                           : state);
  // write to SDRAM when not in reset and state == 0
  sd_rw       <= ~reset && (state == 0);
  // tell the controller the state is valid when 
  // writting (state == 0) or reading (state == 1)
  sd_in_valid <= ~reset && (state == 0 || state == 1);
  // we always store TEST_VALUE
  sd_data_in  <= `TEST_VALUE;
end

endmodule
