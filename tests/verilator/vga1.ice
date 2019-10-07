algorithm main(
  output uint4 vga_r,
  output uint4 vga_g,
  output uint4 vga_b,
  output uint1 vga_hs,
  output uint1 vga_vs
) {

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

  uint1  active = 0;
  uint10 pix_x  = 0;
  uint10 pix_y  = 0;

  HS_START := H_FRT_PORCH;
  HS_END   := H_FRT_PORCH + H_SYNCH;
  HA_START := H_FRT_PORCH + H_SYNCH + H_BCK_PORCH;
  H_END    := H_FRT_PORCH + H_SYNCH + H_BCK_PORCH + H_RES;

  VS_START := V_FRT_PORCH;
  VS_END   := V_FRT_PORCH + V_SYNCH;
  VA_START := V_FRT_PORCH + V_SYNCH + V_BCK_PORCH;
  V_END    := V_FRT_PORCH + V_SYNCH + V_BCK_PORCH + V_RES;

  vga_r := 15;
  vga_g := 0;
  vga_b := 0;

  vga_hs := ~((xcount >= HS_START && xcount < HS_END));
  vga_vs := ~((ycount >= VS_START && ycount < VS_END));

  active := (xcount >= HA_START && xcount < H_END)
         && (ycount >= VA_START && ycount < V_END);

  xcount = H_END;
  ycount = V_END;

  while (1) {

    if (active) {

      pix_x = xcount - HA_START;
      pix_y = ycount - VA_START;

      vga_r = pix_x >> 6;
      vga_g = pix_y >> 5;

    }

    xcount = xcount + 1;
    if (xcount == H_END) {
      xcount = 0;
      ycount = ycount + 1;
    }
    if (ycount == V_END) {
      xcount = 0;
      ycount = 0;
    }

  }

}

