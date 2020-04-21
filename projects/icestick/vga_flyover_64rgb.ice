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

  uint$div_width$ inv_y     = 0;  
  uint$div_width$ cur_inv_y = 0;  

  uint9 offs_y = 0;
  uint8 u      = 0;
  uint8 v      = 0;

  uint16 pos_u  = 1024;
  uint16 pos_v  = 1024;

  uint7 lum    = 0;
  uint1 floor  = 0;

  div$div_width$ div(
    ret :> inv_y
  );

  pix_r  := 0; pix_g := 0; pix_b := 0;
  
  // ---------- show time!
  while (1) {

	  // display frame
	  while (pix_vblank == 0) {

      if (pix_active) {
      
        if (pix_y < 240) {
          offs_y = $240 + 32$ - pix_y;
          floor  = 0;
        } else {
          offs_y = pix_y - $240 - 32$;
          floor  = 1;
        }
        
        if (offs_y >= $32 + 3$ && offs_y < 200) {
        
          if (pix_x == 0) {
            // read result from previous
            cur_inv_y = inv_y;
            if (cur_inv_y[3,7] <= 70) {
              lum = 70 - cur_inv_y[3,7];
              if (lum > 63) {
                lum = 63;
              }
            } else {
              lum = 0;
            }
            // divide for next line
            div <- (22000,offs_y);
          }

          u = pos_u + ((pix_x - 320) * cur_inv_y) >> 8;
          v = pos_v + cur_inv_y[0,6];
          
          if (u[5,1] ^ v[5,1]) {
            if (u[4,1] ^ v[4,1]) {
              pix_r = lum;
              pix_g = lum;
              pix_b = lum;
            } else {
              pix_r = lum[1,6];
              pix_g = lum[1,6];
              pix_b = lum[1,6];
            }
          } else {
            if (u[4,1] ^ v[4,1]) {
              if (floor) {
                pix_g = lum;
              } else {
                pix_b = lum;
              }
            } else {
              if (floor) {
                pix_g = lum[1,6];
              } else {
                pix_b = lum[1,6];
              }
            }
          }          
        }
      
      }
        
    }
    // prepare next    
    pos_u = pos_u + 1024;
    pos_v = pos_v + 1;    
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
