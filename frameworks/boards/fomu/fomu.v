// credits: rob-ng15 - see also https://github.com/rob-ng15/Silice-Playground/
`define FOMU 1
`default_nettype none
$$FOMU     = 1
$$HARDWARE = 1
$$NUM_LEDS = 3

// Correctly map pins for the iCE40UP5K SB_RGBA_DRV hard macro.
// The variables EVT, PVT and HACKER are set from the yosys commandline e.g. yosys -D HACKER=1
`ifdef EVT
`define BLUEPWM  RGB0PWM
`define REDPWM   RGB1PWM
`define GREENPWM RGB2PWM
`elsif HACKER
`define BLUEPWM  RGB0PWM
`define GREENPWM RGB1PWM
`define REDPWM   RGB2PWM
`elsif PVT
`define GREENPWM RGB0PWM
`define REDPWM   RGB1PWM
`define BLUEPWM  RGB2PWM
`else
`error_board_not_supported
`endif

module top(
  // LED outputs
  output  rgb0,
  output  rgb1,
  output  rgb2,
  // USB Pins
  output  usb_dp,
  output  usb_dn,
  output  usb_dp_pu,
`ifdef SPI
  // SPI
  output  spi_mosi,
  input   spi_miso,
  output  spi_clk,
  output  spi_cs,
`endif
`ifdef PADS
  // USER pads
  input   user_1,
  input   user_2,
  input   user_3,
  input   user_4,
`endif
`ifdef OLED
  // OLED
  output  user_1,
  output  user_2,
  output  user_3,
  output  user_4,
`endif
  // 48MHz Clock Input
  input   clki
);

    wire __main_clk;
    
`ifdef USB
    wire __main_usb_dp;
    wire __main_usb_dn;
    wire __main_usb_dp_pu;
    assign usb_dp    = __main_usb_dp;
    assign usb_dn    = __main_usb_dn;
    assign usb_dp_pu = __main_usb_dp_pu;
`else
    // Assign USB pins to "0" so as to disconnect Fomu from
    // the host system.  Otherwise it would try to talk to
    // us over USB, which wouldn't work since we have no stack.
    assign usb_dp = 1'b0;
    assign usb_dn = 1'b0;
    assign usb_dp_pu = 1'b0;
`endif

`ifdef SPI
    wire __main_spi_mosi;
    wire __main_spi_clk;
    wire __main_spi_cs;
    assign spi_mosi = __main_spi_mosi;
    assign spi_clk  = __main_spi_clk;
    assign spi_cs   = __main_spi_cs;
`endif

    // Connect to system clock (with buffering)
    wire clk;
    SB_GB clk_gb (
        .USER_SIGNAL_TO_GLOBAL_BUFFER(clki),
        .GLOBAL_BUFFER_OUTPUT(clk)
    );

    wire [2:0] __main_leds;

`ifdef OLED
`ifdef PADS
`error_cannot_use_both_PADS_and_OLED_not_enough_pins
`endif
    wire __main_oled_clk;
    wire __main_oled_mosi;
    wire __main_oled_csn;
    wire __main_oled_resn;
    wire __main_oled_dc;

    //assign user_1 = __main_oled_mosi;
    //assign user_2 = __main_oled_clk;
    //assign user_3 = __main_oled_resn;
    //assign user_4 = __main_oled_dc;
    
   // flip-flop on outputs to ensure there is no routing delay 
   SB_IO #(
     .PIN_TYPE(5'b0101_00)
   ) reliable_ios[3:0] (
       .PACKAGE_PIN({user_1,user_2,user_3,user_4}),
       .D_OUT_0({__main_oled_mosi, __main_oled_clk, __main_oled_resn, __main_oled_dc}),
       .OUTPUT_CLK({4{__main_clk}})
   );
   
`endif

    reg [63:0] RST_d;
    reg [63:0] RST_q;

    reg ready = 0;

    always @* begin
    RST_d = RST_q >> 1;
    end

    always @(posedge clk) begin
    if (ready) begin
        RST_q <= RST_d;
    end else begin
        ready <= 1;
        RST_q <= 64'b111111111111111111111111111111111111111111111111111111111111;
    end
    end

    wire reset_main;
    assign reset_main = RST_q[0];
    wire run_main;
    assign run_main = 1'b1;

    M_main __main(
    .clock        (clk),
    .out_clock    (__main_clk),
    .reset        (RST_q[0]),
    .out_leds     (__main_leds),
`ifdef USB
    .out_usb_dp   (__main_usb_dp),
    .out_usb_dn   (__main_usb_dn),
    .out_usb_dp_pu(__main_usb_dp_pu),
`endif
`ifdef SPI
    .out_spi_mosi (__main_spi_mosi),
    .in_spi_miso  (spi_miso),
    .out_spi_clk  (__main_spi_clk),
    .out_spi_cs   (__main_spi_cs),
`endif
`ifdef OLED
    .out_oled_mosi(__main_oled_mosi),
    .out_oled_clk (__main_oled_clk),
    .out_oled_csn (__main_oled_csn),
    .out_oled_dc  (__main_oled_dc),
    .out_oled_resn(__main_oled_resn),
`endif
`ifdef PADS
    .in_user_pads({user_4,user_3,user_2,user_1}),
`endif
    .in_run       (run_main)
    );

    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),       // half current
        .RGB0_CURRENT("0b000011"),  // 4 mA
        .RGB1_CURRENT("0b000011"),  // 4 mA
        .RGB2_CURRENT("0b000011")   // 4 mA
    ) RGBA_DRIVER (
        .CURREN(1'b1),
        .RGBLEDEN(1'b1),
        .`BLUEPWM (__main_leds[0]),     // Blue
        .`REDPWM  (__main_leds[1]),      // Red
        .`GREENPWM(__main_leds[2]),    // Green
        .RGB0(rgb0),
        .RGB1(rgb1),
        .RGB2(rgb2)
    );

endmodule
