// SL 2020-04-22
// A rotating texture using BRAM

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
  
  bram uint18 tbl[$32*32$] = {
$$image_table('tile.tga',6)
  };

  bram int10 cosine[256] = {
$$for i=0,255 do
    $math.floor(511.0 * math.cos(2*math.pi*i/255))$,
$$end
  };
  
  pix_r := 0; pix_g := 0; pix_b := 0;  
  // ---------- show time!
  tbl.wenable = 0; cosine.wenable = 0; // we only read in brams
  while (1) {
	  // display frame
	  while (pix_vblank == 0) {
      if (pix_active) {      
        pix_b = tbl.rdata[0,6];
        pix_g = tbl.rdata[6,6];
        pix_r = tbl.rdata[12,6];
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
        // tbl bram access
        tbl.addr = ((u>>11)&31) + (((v>>11)&31)<<5);
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
