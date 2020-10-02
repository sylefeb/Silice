// SL 2019-10
// -------------------------

algorithm vga(
  output! uint1  vga_hs,
  output! uint1  vga_vs,
  output! uint1  active,
  output! uint1  vblank,
  output! uint10 vga_x,
  output! uint10 vga_y
) <autorun> {

  uint10 H_FRT_PORCH = 16;
  uint10 H_SYNCH     = 96;
  uint10 H_BCK_PORCH = 48;
  uint10 H_RES       = 640;

  uint10 V_FRT_PORCH = 10;
  uint10 V_SYNCH     = 2;
  uint10 V_BCK_PORCH = 33;
  uint10 V_RES       = 480;

  uint10 HS_START = 0;
  uint10 HS_END   = 0;
  uint10 HA_START = 0;
  uint10 H_END    = 0;

  uint10 VS_START = 0;
  uint10 VS_END   = 0;
  uint10 VA_START = 0;
  uint10 V_END    = 0;

  uint10 xcount = 0;
  uint10 ycount = 0;

  HS_START := H_FRT_PORCH;
  HS_END   := H_FRT_PORCH + H_SYNCH;
  HA_START := H_FRT_PORCH + H_SYNCH + H_BCK_PORCH;
  H_END    := H_FRT_PORCH + H_SYNCH + H_BCK_PORCH + H_RES;

  VS_START := V_FRT_PORCH;
  VS_END   := V_FRT_PORCH + V_SYNCH;
  VA_START := V_FRT_PORCH + V_SYNCH + V_BCK_PORCH;
  V_END    := V_FRT_PORCH + V_SYNCH + V_BCK_PORCH + V_RES;

  vga_hs := ~((xcount >= HS_START && xcount < HS_END));
  vga_vs := ~((ycount >= VS_START && ycount < VS_END));

  active := (xcount >= HA_START && xcount < H_END)
         && (ycount >= VA_START && ycount < V_END);
  vblank := (ycount < VA_START);

  xcount = 0;
  ycount = 0;

  while (1) {

      vga_x = (active) ? xcount - HA_START : 0;
      vga_y = (vblank) ? 0 : ycount - VA_START;

    if (xcount == H_END-1) {
      xcount = 0;
      if (ycount == V_END-1) {
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
