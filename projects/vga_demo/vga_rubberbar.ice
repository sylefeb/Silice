// SL 2020-04-23
// Roto-rubber-bar, old-school classic!
// MIT license, see LICENSE_MIT in Silice repo root

$include('vga_demo_main.ice')

// -------------------------

algorithm frame_display(
  input   uint10 pix_x,
  input   uint10 pix_y,
  input   uint1  pix_active,
  input   uint1  pix_vblank,
  output! uint$color_depth$ pix_r,
  output! uint$color_depth$ pix_g,
  output! uint$color_depth$ pix_b
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
