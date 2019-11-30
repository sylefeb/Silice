
$include('../common/divint16.ice')
$include('../common/vga_sdram_main_mojo.ice')

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
  div16  div;

  int16 qp0x = -400;
  int16 qp0y =   40;
  int16 qp1x =  400;
  int16 qp1y =   70;

  subroutine draw_quad(
    // quad
    input  int16 p0x,
	input  int16 p0y,
    input  int16 p1x,
	input  int16 p1y,
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

    int16 h     = 100;
    int16 ynear = 3;
    
	int16 scr0x = 0;
	int16 scr0x = 0;
	int16 scrix = 0;
	int16 d10x  = 0;
	int16 d10y  = 0;
    int16 hscr  = 0;
    int16 dscr  = 0;
	
    scr0x = ynear * p0x;
	(scr0x) <- div <- (scr0x,p0y);
    scr1x = ynear * p1x;
	(scr1x) <- div <- (scr1x,p1y);
	d10x  = p1x - p0x;
	d10y  = p1y - p0y;
 	
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
      }
	
	  // draw quad column
	  scrix = pix_x - 160;
      if (scrix >= scr0x && scrix < scr1x) {
	  
	    hscr = h * (scrix * d10y - ynear * d10x);
		dscr = p0x * d10y - p0y * d10x;
		(hscr) <- div <- (hscr,dscr);
		
		if (hscr > 99) {
		  hscr = 99;
		}
		pix_y = 100 - hscr;
        while (pix_y < 100 + hscr) {
          // write to sdram
          while (1) {
            if (sbusy == 0) {        // not busy?
              sdata_in    = 1;
              saddr       = (pix_x + (pix_y << 8) + (pix_y << 6)) >> 2; // * 320 / 4
              swbyte_addr = pix_x & 3;
              sin_valid   = 1; // go ahead!
              break;
            }
          }          
        }
		
      }
	  
	  pix_x = pix_x + 1;
	  
	}
	
	return;
  }  
  
  vsync_filtered ::= vsync;

  sin_valid := 0; // maintain low (pulses high when needed)

  srw = 1;  // write

  while (1) {

    // draw
    () <- draw_quad <- (qp0x,qp0y, qp1x,qp1y);
	
    // wait for vsync
    while (vsync_filtered == 1) {}
    while (vsync_filtered == 0) {}

  }
}

// ------------------------- 
