// SL 2019-10
//
//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

algorithm vga(
  output uint1  vga_hs,
  output uint1  vga_vs,
  output uint1  active,
  output uint1  vblank,
  output uint10 vga_x,
  output uint10 vga_y
) <autorun> {

// we use the pre-processor to compute some bounds
$$H_FRT_PORCH = 16
$$H_SYNCH     = 96
$$H_BCK_PORCH = 48
$$H_RES       = 640
//
$$V_FRT_PORCH = 10
$$V_SYNCH     = 2
$$V_BCK_PORCH = 33
$$V_RES       = 480
//
$$if not VGA_VA_END then
$$VGA_VA_END = V_RES
$$end
//
$$HS_START = H_FRT_PORCH
$$HS_END   = H_FRT_PORCH + H_SYNCH
$$HA_START = H_FRT_PORCH + H_SYNCH + H_BCK_PORCH
$$H_END    = H_FRT_PORCH + H_SYNCH + H_BCK_PORCH + H_RES
//
$$VS_START = V_FRT_PORCH
$$VS_END   = V_FRT_PORCH + V_SYNCH
$$VA_START = V_FRT_PORCH + V_SYNCH + V_BCK_PORCH
$$V_END    = V_FRT_PORCH + V_SYNCH + V_BCK_PORCH + V_RES

  uint10 xcount(0);
  uint10 ycount(0);

  uint10 pix_x     <:: (xcount - $HA_START$);
  uint10 pix_y     <:: (ycount - $VA_START$);

  uint1  active_h  <:: (xcount >= $HA_START$ && xcount < $H_END$);
  uint1  active_v  <:: (ycount >= $VA_START$ && ycount < $VA_START + VGA_VA_END$);

  active           :=  active_h && active_v;

  vga_hs           :=  ~((xcount >= $HS_START$ && xcount < $HS_END$));
  vga_vs           :=  ~((ycount >= $VS_START$ && ycount < $VS_END$));

  vblank           :=  (ycount < $VA_START$);

  always {

    vga_x = active_h ? pix_x : 0;
    vga_y = active_v ? pix_y : 0;

    if (xcount == $H_END-1$) {
      xcount = 0;
      if (ycount == $V_END-1$) {
        ycount = 0;
      } else {
        ycount = ycount + 1;
	    }
    } else {
      xcount = xcount + 1;
	  }
  }

}

// -------------------------
