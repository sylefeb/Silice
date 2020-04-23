// SL 2020-04-19
// Copper bars, AMIGA style!

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

  uint7 wave[64] = {
$$for i=0,63 do
    $math.floor(127.0 * (0.5+0.5*math.cos(math.pi + 2*math.pi*i/63)))$,
$$end
  };

  uint$color_depth$ v = 0;
  uint6 frame  = 0;  
  int9  pos[4] = {0,0,0,0};
  
  pix_value := 0;
  // ---------- show time!
  while (1) {

	  // display frame
	  while (pix_vblank == 0) {
      if (pix_active) {
        4x {
          if (pix_y + 20 > pos[__id] && pix_y < pos[__id] + 20) {
            v = ((wave[pix_y-pos[__id] + 32]>>1) * (__id+5)) >> 3;
            pix_r = v;
            pix_g = v;
            pix_b = v;
          }
        }
      }
    }    
    // prepare next
    frame = frame + 1;    
    4x {
      pos[__id] = $240 - 127$ + (wave[(frame + (__id << 3)) & 63] << 1);
    }
    // wait for sync
    while (pix_vblank == 1) {} 
  }
}

// -------------------------
