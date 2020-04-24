// ------------------------- 

$include('../common/video_sdram_main.ice')

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
  input  uint1  vsync,
  output uint1  fbuffer
) {

  uint16 shift = 0;
  uint1  vsync_filtered = 0;
   
  subroutine bands(
    reads   shift,
    reads   sbusy,
    writes  sdata_in,
    writes  saddr,
    writes  swbyte_addr,
    writes  sin_valid,
    reads   fbuffer
  ) {
    uint9  pix_x   = 0;
    uint8  pix_y   = 0;
    uint8  pix_palidx = 0;
    	
    pix_y = 0;  
    while (pix_y < 200) {
      pix_x  = 0;
      while (pix_x < 320) {
		
        // compute pixel palette index
        pix_palidx = pix_x + shift;
		
        // write to sdram
        while (1) {          
          if (sbusy == 0) {        // not busy?
            sdata_in  = pix_palidx;
            swbyte_addr = pix_x & 3;
            saddr     = {~fbuffer,21b0} | ((pix_x + (pix_y << 8) + (pix_y << 6)) >> 2); // * 320 / 4
            sin_valid = 1; // go ahead!
            break;
          }
        }
		
        pix_x = pix_x + 1;
      }
      pix_y = pix_y + 1;
    }
    return;
  }
  
  vsync_filtered ::= vsync;

  sin_valid   := 0; // maintain low (pulses high when needed)

  srw   = 1;  // write

  while (1) {

    // draw a frame
	  $display("drawing ...");
    () <- bands <- ();
	  $display("done.");
	
    // increment shift    
    shift = shift + 1;
    
    // wait for frame to end
    while (vsync_filtered == 0) {}

    // swap buffers
    fbuffer = ~fbuffer;

  }
}

// ------------------------- 
