// SL 2020-04-23
// Main file for all vga demo projects
// -------------------------

// VGA driver
$include('../../common/vga.ice')

$$if MOJO then
// Clock
import('../common/mojo_clk_100_25.v')
$$end

$$if ICESTICK then
// Clock
import('../common/icestick_clk_25.v')
$$end

$$if DE10NANO then
// Clock
import('../common/de10nano_clk_100_25.v')
$$end

$$if HARDWARE then
// Reset
import('../common/reset_conditioner.v')
$$end

// -------------------------

$$if SIMULATION then
algorithm pll(
  output  uint1 video_clock,
  output  uint1 video_reset,
) <autorun>
{
  uint3 counter = 0;
  uint8 trigger = 8b11111111;
  
  video_clock   := counter[1,1]; // x4 slower (25 MHz)
  video_reset   := (trigger > 0);
  
  always {	  
    counter = counter + 1;
	  trigger = trigger >> 1;
  }
}
$$end

// -------------------------

algorithm main(
$$if MOJO then
  output! uint8 led,
  output! uint1 spi_miso,
  input   uint1 spi_ss,
  input   uint1 spi_mosi,
  input   uint1 spi_sck,
  output! uint4 spi_channel,
  input   uint1 avr_tx,
  output! uint1 avr_rx,
  input   uint1 avr_rx_busy,
$$end
$$if MOJO or VERILATOR or ULX3S or DE10NANO then
  // SDRAM
  output! uint1  sdram_cle,
  output! uint1  sdram_dqm,
  output! uint1  sdram_cs,
  output! uint1  sdram_we,
  output! uint1  sdram_cas,
  output! uint1  sdram_ras,
  output! uint2  sdram_ba,
  output! uint13 sdram_a,
$$if VERILATOR then
  output! uint1  sdram_clock,
  input   uint8  sdram_dq_i,
  output! uint8  sdram_dq_o,
  output! uint1  sdram_dq_en,
$$else
  output! uint1  sdram_clk,
  inout   uint8  sdram_dq,
$$end
$$end
$$if SIMULATION then
  output! uint1 video_clock,
$$end
$$if ICESTICK then
  output! uint1 led0,
  output! uint1 led1,
  output! uint1 led2,
  output! uint1 led3,
  output! uint1 led4,
$$end
$$if DE10NANO then
  output! uint8 led,
  output! uint4 kpadC,
  input   uint4 kpadR,
  output! uint1 lcd_rs,
  output! uint1 lcd_rw,
  output! uint1 lcd_e,
  output! uint8 lcd_d,
  output! uint1 oled_din,
  output! uint1 oled_clk,
  output! uint1 oled_cs,
  output! uint1 oled_dc,
  output! uint1 oled_rst,  
$$end
$$if ULX3S then
  output! uint8 led,
  input   uint7 btn,
$$end
  output! uint$color_depth$ video_r,
  output! uint$color_depth$ video_g,
  output! uint$color_depth$ video_b,
  output! uint1 video_hs,
  output! uint1 video_vs
) 
$$if not ULX3S then
<@video_clock,!video_reset> 
$$end
{
  uint1 video_reset = 0;

$$if HARDWARE then
  uint1 video_clock = 0;
$$if MOJO then
  uint1 sdram_clock = 0;
  // --- clock
  clk_100_25 clk_gen (
    CLK_IN1  <: clock,
    CLK_OUT1 :> sdram_clock,
    CLK_OUT2 :> video_clock
  );
  // --- sdram reset
  uint1 sdram_reset = 0;
  reset_conditioner sdram_rstcond (
    rcclk <: sdram_clock,
    in  <: reset,
    out :> sdram_reset
  );
$$elseif ICESTICK then
  // --- clock
  icestick_clk_25 clk_gen (
    clock_in  <: clock,
    clock_out :> video_clock,
    lock      :> led4
  );
$$elseif DE10NANO then
  // --- clock
  uint1 sdram_clock = 0;
  uint1 pll_lock = 0;
  de10nano_clk_100_25 clk_gen(
    refclk   <: clock,
    rst      <: reset,
    outclk_0 :> sdram_clock,
    outclk_1 :> video_clock,
    locked   :> pll_lock
  ); 
$$end
  // --- video reset
  reset_conditioner vga_rstcond (
    rcclk <: video_clock,
    in  <: reset,
    out :> video_reset
  );
$$else
  // --- simulation pll
  pll clockgen<@clock,!reset>(
    video_clock   :> video_clock,
    video_reset   :> video_reset,
  );  
$$end

  uint1  active = 0;
  uint1  vblank = 0;
  uint10 pix_x  = 0;
  uint10 pix_y  = 0;

  vga vga_driver (
    vga_hs :> video_hs,
	  vga_vs :> video_vs,
	  active :> active,
	  vblank :> vblank,
	  vga_x  :> pix_x,
	  vga_y  :> pix_y
  );

  frame_display display (
	  pix_x      <: pix_x,
	  pix_y      <: pix_y,
	  pix_active <: active,
	  pix_vblank <: vblank,
	  pix_r      :> video_r,
	  pix_g      :> video_g,
	  pix_b      :> video_b,
    <:auto:>
  );

  uint8 frame  = 0;

$$if MOJO then
  // unused pins
  spi_miso := 1bz;
  avr_rx := 1bz;
  spi_channel := 4bzzzz;
$$end

$$if SIMULATION then
  // we count a number of frames and stop
  while (frame < 3) {
$$else
  // forever
  while (1) {
$$end
  
    while (vblank == 1) { }
	  $display("vblank off");
    while (vblank == 0) { }
    $display("vblank on");
    frame = frame + 1;

  }
}

// -------------------------
