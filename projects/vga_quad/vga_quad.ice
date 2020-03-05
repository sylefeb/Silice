// ------------------------- 

$$div_width=32
$include('../common/divint_any.ice')
$$mul_width=32
$include('../common/mulint_any.ice')

$include('../common/vga_sdram_main.ice')

// ------------------------- 

algorithm frame_drawer(
  output uint23 saddr,
  output uint2  swbyte_addr,
  output uint1  srw,
  output uint32 sdata_in,
  output uint1  sin_valid,
  input  uint32 sdata_out,
  input  uint1  sbusy,
  input  uint1  sout_valid,
  input  uint1  vsync
) {

  uint1  vsync_filtered = 0;
  div32  div;
  mul32  mul;

  int32 qp0x = -400;
  int32 qp0y =   20;
  int32 qp1x =  400;
  int32 qp1y =   20;
  uint1 dir0 =   0;
  uint1 dir1 =   0;

  subroutine clear_screen(
  	// sdram
    reads   sbusy,
    writes  sdata_in,
    writes  saddr,
    writes  swbyte_addr,
    writes  sin_valid
  )
  {
    uint9  pix_x      = 0;
    uint8  pix_y      = 0;
	  
    pix_x  = 0;
    while (pix_x < 320) {	
	    // clear column
	    pix_y = 0;
      while (pix_y < 200) {
        // write to sdram
        while (1) {
          if (sbusy == 0) {        // not busy?
            sdata_in    = 0;
            saddr       = (pix_x + (pix_y << 8) + (pix_y << 6)) >> 2; // * 320 / 4
            swbyte_addr = pix_x & 3;
            sin_valid   = 1; // go ahead!
            break;
          }
        }          
        pix_y = pix_y + 1;
      }	  
	    pix_x = pix_x + 1;
	  }	
	  return;
  }

  subroutine draw_quad(
    // quad
    input  int32 p0x,
	  input  int32 p0y,
    input  int32 p1x,
	  input  int32 p1y,
	  // sdram
    reads   sbusy,
    writes  sdata_in,
    writes  saddr,
    writes  swbyte_addr,
    writes  sin_valid
  )
  {
    int32 pix_x = 0;
    int32 pix_y = 0;

    int32 h     = 100;
    int32 ynear = 4;
    
	  int32 scr0x = 0;
	  int32 scr0y = 0;
	  int32 scr1x = 0;
	  int32 scr1y = 0;
	  int32 scrix = 0;
	  int32 d10x  = 0;
	  int32 d10y  = 0;
    
    int32 hscr      = 0;
    int32 hscr_tmp  = 0;
    int32 dscr      = 0;
    int32 dscr_inv  = 0;
    int32 fp        = 32d1048576;
	
    int32 yn_d10x   = 0;
    int32 h_yn_d10x = 0;
    int32 h_d10y    = 0;
  
    scr0x = ynear * p0x;
    scr1x = ynear * p1x;

	  (scr0x) <- div <- (scr0x,p0y);
	  (scr1x) <- div <- (scr1x,p1y);

	  d10x  = p1x - p0x;
	  d10y  = p1y - p0y;

    // dscr = p0x * d10y - p0y * d10x;

    dscr      =   p0x * d10y;   
    yn_d10x   = ynear * d10x;
++:
    dscr      = dscr - p0y * d10x;
    h_yn_d10x = h * yn_d10x;
    h_d10y    = h * d10y;

    if (scr0x < -160) {
      scr0x = -160;
    }
    if (scr0x > 159) {
      scr0x = 159;
    }
    if (scr1x < -160) {
      scr1x = -160;
    }
    if (scr1x > 159) {
      scr1x = 159;
    }
++:   
    (dscr_inv) <- div <- (fp,dscr);
    
    scrix = scr0x;
    while (scrix < scr1x) {
	
	    // draw quad column  
	    // hscr = h * (scrix * d10y - ynear * d10x); 	    
      
      // hscr = scrix * h_d10y - h_yn_d10x;      
      (hscr_tmp) <- mul <- (scrix,h_d10y);
      hscr = hscr_tmp - h_yn_d10x;
      
++:
      //hscr = (hscr * dscr_inv) >> 20; // FP mul inverse, computes (hscr) <- div <- (hscr,dscr);      
      (hscr_tmp) <- mul <- (hscr,dscr_inv);
      hscr = hscr_tmp >> 20;

      if (hscr < 0) {
        hscr = 0; // wtf? overflow?
      }
      if (hscr > 99) {
        hscr = 99;
      }
      pix_y = 100 - hscr;
      
      while (pix_y < 32d100 + hscr) {
        // write to sdram
        pix_x = scrix + 160;
        while (1) {
          if (sbusy == 0) {        // not busy?
            sdata_in    = 15; // palette id
            saddr       = (pix_x + (pix_y << 32d8) + (pix_y << 32d6)) >> 32d2; // * 320 / 4
            swbyte_addr = pix_x & 3;
            sin_valid   = 1; // go ahead!
            break;
          }
        }          
        pix_y = pix_y + 1;
      }		

      scrix = scrix + 1;
	  }	
	  return;
  }  
  
  vsync_filtered ::= vsync;

  sin_valid := 0; // maintain low (pulses high when needed)

  srw = 1;  // write

  while (1) {

    // clear
	  () <- clear_screen <- ();
    // draw
    () <- draw_quad <- (qp0x,qp0y, qp1x,qp1y);
	
    // wait for vsync
    while (vsync_filtered == 1) {}
    while (vsync_filtered == 0) {}

    // wait for vsync
    while (vsync_filtered == 1) {}
    while (vsync_filtered == 0) {}

    if (dir0 == 0) {
      qp0y = qp0y + 1;
      if (qp0y > 80) {
        dir0 = 1;
      }
    } else {
      qp0y = qp0y - 1;
      if (qp0y < 10) {
        dir0 = 0;
      }
    }

    if (dir1 == 0) {
      qp1y = qp1y + 2;
      if (qp1y > 80) {
        dir1 = 1;
      }
    } else {
      qp1y = qp1y - 1;
      if (qp1y < 10) {
        dir1 = 0;
      }
    }

  }
}

// ------------------------- 
