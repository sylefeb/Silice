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

  uint8  frame = 0;
  uint8  angle = 0;
  int20  u     = 0;
  int20  v     = 0;
  int20  cos   = 0;
  int20  sin   = 0;
  int20  cornerx  = -320;
  int20  cornery  = -240;
  int20  corneru  = 0;
  int20  cornerv  = 0;
  int20  deltau_x = 0;
  int20  deltau_y = 0;
  int20  deltav_x = 0;
  int20  deltav_y = 0;
  
  bram uint18 table[$32*32$] = {
$$image_table('tile.tga',6)
  };

  bram int10 cosine[256] = {
$$for i=0,255 do
    $math.floor(511.0 * math.cos(2*math.pi*i/255))$,
$$end
  };
  
  pix_r := 0; pix_g := 0; pix_b := 0;  
  // ---------- show time!
  table.wenable = 0; cosine.wenable = 0; // we only read in brams
  while (1) {
	  // display frame
	  while (pix_vblank == 0) {
      if (pix_active) {      
        pix_b = table.rdata[0,6];
        pix_g = table.rdata[6,6];
        pix_r = table.rdata[12,6];
        // update u,v
        if (pix_x == 0) {
          u = corneru;
          v = cornerv;
        } else {
          if (pix_x == 639) {
            corneru = corneru + deltau_y;
            cornerv = cornerv + deltav_y;
          } else {
            u = u + deltau_x;
            v = v + deltav_x;
          }
        }
        // table bram access
        table.addr = ((u>>11)&31) + (((v>>11)&31)<<5);
        // access during loop (one cycle to go back)
      }
    }
    // prepare next (we are in vblank, there is time)
    frame       = frame + 1;
    cosine.addr = frame;
++:    
    angle       = ((512+cosine.rdata) >> 2);
    cosine.addr = angle;
++: // sine bram access
    cos = cosine.rdata;
    cosine.addr = angle + 64;
++: // sine bram access
    sin = cosine.rdata;
    // prepare scanline with mapping
    corneru  = (cornerx * cos - cornery * sin);
    cornerv  = (cornerx * sin + cornery * cos);
    deltau_x = cos;
    deltau_y = - sin;
    deltav_x = sin;
    deltav_y = cos;
    u        = corneru;
    v        = cornerv;
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
