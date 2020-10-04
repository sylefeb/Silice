// SL 2020-04-23
// Main file for all vga demo projects
// -------------------------

// VGA driver
$include('../common/vga.ice')

$$if CROSSLINKNX_EVN then
// Clock
import('../common/crosslink_nx_evn_clk_25.v')
$$end

$$if MOJO then
// Clock
import('../common/mojo_clk_100_25.v')
$$end

$$if ICEBREAKER then
// Clock
import('../common/icebreaker_clk_25.v')
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
  output! uint$NUM_LEDS$    leds,
  output! uint$color_depth$ video_r,
  output! uint$color_depth$ video_g,
  output! uint$color_depth$ video_b,
  output! uint1             video_hs,
  output! uint1             video_vs,
$$if SIMULATION then
  output! uint1             video_clock,
$$end
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
$$elseif CROSSLINKNX_EVN then
  // --- clock
  uint1 pll_lock    = 0;
  crosslink_nx_evn_clk_25 clk_gen (
    clki_i  <: clock,
    rst_i   <: reset,
    clkop_o :> video_clock,
    lock_o  :> pll_lock
  );
$$elseif ICESTICK then
  // --- clock
  uint1 pll_lock    = 0;
  icestick_clk_25 clk_gen (
    clock_in  <: clock,
    clock_out :> video_clock,
    lock      :> pll_lock
  );
$$elseif ICEBREAKER then
  // --- clock
  icebreaker_clk_25 clk_gen (
    clock_in  <: clock,
    clock_out :> video_clock
  );
$$elseif DE10NANO then
  // --- clock
  uint1 sdram_clock = 0;
  uint1 pll_lock    = 0;
  de10nano_clk_100_25 clk_gen(
    refclk   <: clock,
    rst      <: reset,
    outclk_0 :> sdram_clock,
    outclk_1 :> video_clock,
    locked   :> pll_lock
  ); 
$$end
  // --- video reset
  reset_conditioner vga_rstcond(
    rcclk <: video_clock,
    in    <: reset,
    out   :> video_reset
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

$$if SIMULATION then
  // we count a number of frames and stop
  while (frame < 32) {
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
