// -------------------------

// VGA driver
$include('../common/vga.ice')

$$if MOJO then
// Clock
import('../common/mojo_clk_100_25.v')
$$end

$$if ICESTICK then
// Clock
import('../common/icestick_clk_vga.v')
$$end

$$if HARDWARE then
// Reset
import('../common/reset_conditioner.v')
$$end

$$if MOJO then
$$max_color   = 1
$$color_depth = 1
$$else
$$max_color   = 15
$$color_depth = 4
$$end

// -------------------------

algorithm frame_display(
  input   uint10 pix_x,
  input   uint10 pix_y,
  input   uint1  pix_active,
  input   uint1  pix_vblank,
  output! uint4  pix_red,
  output! uint4  pix_green,
  output! uint4  pix_blue
) <autorun> {
  // panning
  uint16 pan_x = 0;
  uint16 x = 0;
  // by default r,g,b are set to zero
  pix_red   := 0;
  pix_green := 0;
  pix_blue  := 0; 
  // ---------- show time!
  while (1) {
	  // display frame
	  while (pix_vblank == 0) {
      if (pix_active) {
        x         = pix_x + pan_x;
        pix_blue  = x[4,$color_depth$];
        pix_green = pix_y[4,$color_depth$];
        pix_red   = 0;
      }      
    }    
    while (pix_vblank == 1) {} // wait for sync
    pan_x = pan_x + 1;
  }
}

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
$$if MOJO or VERILATOR then
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
  output! uint4 video_r,
  output! uint4 video_g,
  output! uint4 video_b,
  output! uint1 video_hs,
  output! uint1 video_vs
) 
$$if HARDWARE then
// on an actual board, the video signal is produced by a PLL
<@video_clock,!video_reset> 
$$end
{

$$if HARDWARE then
  uint1 video_reset = 0;
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
  icestick_clk_vga clk_gen (
    clock_in  <: clock,
    clock_out :> video_clock,
    lock      :> led4
  );
$$end
  // --- video reset
  reset_conditioner vga_rstcond (
    rcclk <: video_clock,
    in  <: reset,
    out :> video_reset
  );
$$end

  uint1  active = 0;
  uint1  vblank = 0;
  uint10 pix_x  = 0;
  uint10 pix_y  = 0;

  vga vga_driver 
$$if HARDWARE then
  <@video_clock,!video_reset>
$$end
  (
    vga_hs :> video_hs,
	  vga_vs :> video_vs,
	  active :> active,
	  vblank :> vblank,
	  vga_x  :> pix_x,
	  vga_y  :> pix_y
  );

  frame_display display
$$if HARDWARE then
  <@video_clock,!video_reset>
$$end  
  (
	  pix_x      <: pix_x,
	  pix_y      <: pix_y,
	  pix_active <: active,
	  pix_vblank <: vblank,
	  pix_red    :> video_r,
	  pix_green  :> video_g,
	  pix_blue   :> video_b
  );

$$if MOJO then
  // unused pins
  spi_miso := 1bz;
  avr_rx := 1bz;
  spi_channel := 4bzzzz;
$$end

  uint8 frame  = 0;

$$if SIMULATION then
  video_clock := clock;
$$end

$$if SIMULATION then
  // we count a number of frames and stop
  while (frame < 8) {
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
