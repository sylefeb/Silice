// -------------------------

// VGA driver
$include('../../common/vga.ice')

$$if not SIMULATION then
// Clock
import('../../common/icestick_clk_vga.v')
// Reset
import('../../common/reset_conditioner.v')
$$end

// Divider
$$div_width    = 16
$$div_unsigned = true
$$div_shrink   = 3
$include('../../common/divint_any.ice')

$$max_color   = 63
$$color_depth = 6

// -------------------------

algorithm frame_display(
  input   uint10 pix_x,
  input   uint10 pix_y,
  input   uint1  pix_active,
  input   uint1  pix_vblank,
  output! uint6  pix_r,
  output! uint6  pix_g,
  output! uint6  pix_b
) <autorun> {

  uint7 wave[128] = {
$$for i=0,127 do
    $math.floor(127.0 * (0.5+0.5*math.sin(2*math.pi*i/127)))$,
$$end
  };

  uint7  frame = 0;
  
  uint10 pos0 = 320;
  uint10 pos1 = 160;
  uint10 pos2 = 240;
  uint10 pos3 = 480;
  uint10 ampl = 0;
  uint10 bar0 = 320;
  uint10 bar1 = 160;
  uint10 bar2 = 240;
  uint10 bar3 = 480;
  
  pix_r  := 0; pix_g := 0; pix_b := 0;

  // ---------- show time!
  while (1) {

	  // display frame
	  while (pix_vblank == 0) {

      if (pix_active) {
        ampl = wave[pix_y[2,7]];
        bar0 = pos0 + ampl;
        bar1 = pos1 + ampl;
        bar2 = pos2 + ampl;
        bar3 = pos3 + ampl;
        if (pix_x >= bar0 && pix_x < bar1) {
          pix_r = 63;
        }
        if (pix_x >= bar1 && pix_x < bar2) {
          pix_g = 63;
        }
        if (pix_x >= bar2 && pix_x < bar3) {
          pix_b = 63;
        }
        if (pix_x >= bar3 && pix_x < bar0) {
          pix_r = 63;
          pix_g = 63;
          pix_b = 63;
        }
      }

    }
    // prepare next
    frame = frame + 1;
    pos0  = $320-128$ + wave[frame];
    pos1  = $320-128$ + wave[(frame + 32)&127];
    pos2  = $320-128$ + wave[(frame + 64)&127];
    pos3  = $320-128$ + wave[(frame + 96)&127];
    // wait for sync
    while (pix_vblank == 1) {} 
  }

}

// -------------------------

algorithm main(
  output! uint1 led0,
  output! uint1 led1,
  output! uint1 led2,
  output! uint1 led3,
  output! uint1 led4,
$$if ICARUS then
  output! uint1 video_clock,
$$end
  output! uint6 video_r,
  output! uint6 video_g,
  output! uint6 video_b,
  output! uint1 video_hs,
  output! uint1 video_vs
) 
$$if not SIMULATION then
<@video_clock,!video_reset> 
$$end
{

$$if not SIMULATION then

  uint1 video_reset = 0;
  uint1 video_clock = 0;
  // --- clock
  icestick_clk_vga clk_gen (
    clock_in  <: clock,
    clock_out :> video_clock,
    lock      :> led4
  );
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
  uint6  pix_value = 0;
  uint3  frame  = 0;
  
  vga vga_driver 
$$if not SIMULATION then  
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
$$if not SIMULATION then
  <@video_clock,!video_reset>
$$end
  (
	  pix_x      <: pix_x,
	  pix_y      <: pix_y,
	  pix_active <: active,
	  pix_vblank <: vblank,
	  pix_r      :> video_r,
	  pix_g      :> video_g,
	  pix_b      :> video_b
  );

$$if SIMULATION then
  video_clock := clock;
$$end

$$if SIMULATION then
  $display("starting");
  // we count a number of frames and stop
  while (frame < 2) { 
    while (vblank == 1) { }
	  $display("vblank off");
    while (vblank == 0) { }
    $display("vblank on");
    frame = frame + 1; 
  }
$$else
  // forever
  while (1) { }
$$end
  
}
