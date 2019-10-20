// -------------------------

// Text buffer
import('../common/text_buffer.v')

// -------------------------

algorithm text_display(
  input  uint10 vga_x,
  input  uint10 vga_y,
  input  uint1  vga_active,
  input  uint1  vga_vblank,
  output uint4  vga_red,
  output uint4  vga_green,
  output uint4  vga_blue
) <autorun> {

// Text buffer

uint14 txtaddr   = 0;
uint6  txtdata_r = 0;
uint6  txtdata_w = 0;
uint1  txtwrite  = 0;

text_buffer txtbuf (
  clk     <: clock,
  addr    <: txtaddr,
  wdata   <: txtdata_w,
  rdata   :> txtdata_r,
  wenable <: txtwrite
);

  // ---------- font
  
  $include('../common/font.ice')
   
  // ---------- text display

  uint8  text_i   = 0;
  uint7  text_j   = 0;
  uint3  letter_i = 0;
  uint4  letter_j = 0;
  uint1  pixel    = 0;
  uint12 addr     = 0;

  uint16 next     = 0;

  uint8  lttr     = 0;
  uint11 col      = 0;
  uint11 str_x    = 10;
  uint10 str_y    = 10;

  int32   numb     = -32h1234;
  uint32  numb_tmp = 0;
  uint8   numb_cnt = 0;

  // ---------- string

  uint8  str[] = "HELLO WORLD FROM FPGA";
  uint8  tmp   = 0;
  uint8  step  = 0;

  // --------- print string
  subroutine print_string( 
      readwrites col,
	  readwrites lttr,
	  reads      str,
	  reads      str_x,
	  reads      str_y,
	  writes     txtaddr,
	  writes     txtdata_w,
	  writes     txtwrite
	  )
    col  = 0;
    lttr = str[col];
    while (lttr != 0) {
      if (lttr == 32) {
        lttr = 36;
      } else {
        lttr = lttr - 55;
      }
      txtaddr   = col + str_x + str_y * 80;
      txtdata_w = lttr[0,6];
      txtwrite  = 1;
      col       = col + 1;
      lttr      = str[col];
    }
	txtwrite = 0;
  return;

  // by default r,g,b are set to zero
  vga_red   := 0;
  vga_green := 0;
  vga_blue  := 0;

  // fill buffer with spaces
  txtwrite  = 1;
  next      = 0;
  txtdata_w = 36; // data to write
  while (next < 4800) {
    txtaddr = next;     // address to write
    next    = next + 1; // next
  }
  txtwrite = 0;

  // ---------- show time!

  while (1) {

      // wait until vblank is over
	  while (vga_vblank == 1) { }

	  // display frame
	  while (vga_vblank == 0) {

        vga_blue = vga_y;

		if (letter_j < 8) {
		  letter_i = vga_x & 7;
		  addr     = letter_i + (letter_j << 3) + (txtdata_r << 6);
		  pixel    = letters[ addr ];
		  if (pixel == 1) {
			vga_red   = 15;
			vga_green = 15;
			vga_blue  = 15;
		  }
		}

		if (vga_active && (vga_x & 7) == 7) {   // end of letter
		  text_i = text_i + 1;
		  if (vga_x == 639) {  // end of line
			// back to first column
			text_i   = 0;
			// next letter line
			if (letter_j < 8) {
			  letter_j = letter_j + 1;
			} else {
			  // next row
			  letter_j = 0;
			  text_j   = text_j + 1;
			}
			if (vga_y == 479) {
			  // end of frame
			  text_i   = 0;
			  text_j   = 0;
			  letter_j = 0;
			}
		  }
		}

		txtaddr  = text_i + text_j * 80;

	  }

	  // prepare next frame
	  () <- print_string <- ();
	  str_y = str_y + 2;

  }
}

// -------------------------

algorithm vga(
  input  uint4  vga_r,
  input  uint4  vga_g,
  input  uint4  vga_b,
  output uint1  vga_hs,
  output uint1  vga_vs,
  output uint1  active,
  output uint1  vblank,
  output uint10 pix_x,
  output uint10 pix_y
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

  xcount = H_END;
  ycount = V_END;

  while (1) {

    if (active) {
      pix_x = xcount - HA_START;
      pix_y = ycount - VA_START;
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

// -------------------------

algorithm main(
  output uint4 vga_r,
  output uint4 vga_g,
  output uint4 vga_b,
  output uint1 vga_hs,
  output uint1 vga_vs
) {

  uint1  active = 0;
  uint1  vblank = 0;
  uint10 pix_x  = 0;
  uint10 pix_y  = 0;

  vga vga_driver(
	vga_r  <: vga_r,
	vga_g  <: vga_g,
	vga_b  <: vga_b,
    vga_hs :> vga_hs,
	vga_vs :> vga_vs,
	active :> active,
	vblank :> vblank,
	pix_x  :> pix_x,
	pix_y  :> pix_y
  );

  text_display display(
      vga_x      <: pix_x,
      vga_y      <: pix_y,
      vga_active <: active,
      vga_vblank <: vblank,
      vga_red    :> vga_r,
      vga_green  :> vga_g,
      vga_blue   :> vga_b
  );

  // we count a number of frames and stop

  uint8 frame  = 0;

  while (frame < 2) {
  
    while (vblank == 1) { }

    while (vblank == 0) { }
  
    frame = frame + 1;

  }
}

