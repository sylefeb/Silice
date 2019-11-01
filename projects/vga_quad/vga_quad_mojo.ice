
$include('../common/divint16.ice')
$include('../common/vga_sdram_main_mojo.ice')

// ------------------------- 

algorithm frame_drawer(
  output uint23 saddr,
  output uint1  srw,
  output uint32 sdata_in,
  output uint1  sin_valid,
  input  uint32 sdata_out,
  input  uint1  sbusy,
  input  uint1  sout_valid,
  input  uint1  vsync
) {

  uint1  vsync_filtered = 0;

  uint8  tops[320] = {};
  uint8  btms[320] = {};

  subroutine test_walls(
    writes   tops,
    writes   btms
  )
    uint9  pix_x   = 0;
    while (pix_x < 320) {
      tops[pix_x] = 0;
      btms[pix_x] = pix_x;      
      pix_x = pix_x + 1;
    }
  return;
  
  subroutine draw_walls(
    reads   sbusy,
    writes  sdata_in,
    writes  saddr,
    reads   tops,
    reads   btms,
    writes  sin_valid
  )
    uint9  pix_x   = 0;
    uint8  pix_y   = 0;
    uint8  pix_palidx = 0;
    uint32 fourpix = 0; // accumulate four 8 bit pixels in 32 bits word
	
    pix_y = 0;  
    while (pix_y < 200) {
      pix_x  = 0;
      while (pix_x < 320) {

        // check if this location is within a wall
        if (pix_y >= tops[pix_x] && pix_y < btms[pix_x]) {
          pix_palidx = 1;
        } else {
          pix_palidx = 0;
        }
		    fourpix    = fourpix | (pix_palidx << ((pix_x&3)<<3));		
		    if ((pix_x&3) == 3) {
          // write to sdram
          while (1) {          
            if (sbusy == 0) {        // not busy?
              sdata_in  = fourpix;
              saddr     = (pix_x + (pix_y << 8) + (pix_y << 6)) >> 2; // * 320 / 4
              sin_valid = 1; // go ahead!
              break;
            }
          }
		      // reset accumulator
		      fourpix = 0;		  
		    }

        pix_x = pix_x + 1;
      }
      pix_y = pix_y + 1;
    }
  return;
  
  vsync_filtered ::= vsync;

  sin_valid      := 0; // maintain low (pulses high when needed)

  srw   = 1;  // write

  while (1) {

    // draw a frame
    () <- test_walls <- ();
    () <- draw_walls <- ();
	
    // wait for vsync
    while (vsync_filtered == 1) {}
    while (vsync_filtered == 0) {}

  }
}

// ------------------------- 
