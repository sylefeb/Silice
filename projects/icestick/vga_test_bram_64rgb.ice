// -------------------------

// VGA driver
$include('../../common/vga.ice')

// Clock
import('../../common/icestick_clk_vga.v')

// Reset
import('../../common/reset_conditioner.v')

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

  bram uint6 table[$32*32$] = {
$$for i=0,31 do  
$$for j=0,31 do
$$if (i+j)%2 == 0 then
      63,
$$else
      0,
$$end
$$end
$$end
  };

  pix_r := 0;
  pix_g := 0;
  pix_b := 0;
  
  // ---------- show time!
  table_wenable = 0;
  table_addr = 0;
  while (1) {
	  // display frame
	  while (pix_vblank == 0) {
      if (pix_active) {
      
        pix_r = table_rdata;
        pix_g = table_rdata;
        pix_b = table_rdata;
  
        table_addr = pix_x[0,5] + (pix_y[0,5]<<5);
      }
    }
    while (pix_vblank == 1) {} // wait for sync
  }
  
}

// -------------------------

algorithm main(
  output! uint1 led0,
  output! uint1 led1,
  output! uint1 led2,
  output! uint1 led3,
  output! uint1 led4,
  output! uint1 video_hs,
  output! uint1 video_vs,
  output! uint6 video_r,
  output! uint6 video_g,
  output! uint6 video_b
) 
<@video_clock,!video_reset> 
{

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

  uint1  active = 0;
  uint1  vblank = 0;
  uint10 pix_x  = 0;
  uint10 pix_y  = 0;
  
  vga vga_driver 
  <@video_clock,!video_reset>
  (
    vga_hs :> video_hs,
	  vga_vs :> video_vs,
	  active :> active,
	  vblank :> vblank,
	  vga_x  :> pix_x,
	  vga_y  :> pix_y
  );

  frame_display display
  <@video_clock,!video_reset>
  (
	  pix_x      <: pix_x,
	  pix_y      <: pix_y,
	  pix_active <: active,
	  pix_vblank <: vblank,
	  pix_r      :> video_r,
	  pix_g      :> video_g,
	  pix_b      :> video_b
  );

  
  // forever
  while (1) { }
  
}
