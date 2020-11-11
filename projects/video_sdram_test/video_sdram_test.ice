// ------------------------- 

// debug palette
$$palette = {}
$$for i=1,256 do
$$  palette[i]= (i) | (((i<<1)&255)<<8) | (((i<<2)&255)<<16)
$$end

$include('../common/video_sdram_main.ice')

// ------------------------- 

algorithm frame_drawer(
  output uint8 leds,
  sdram_user    sd,
  input  uint1  sdram_clock,
  input  uint1  sdram_reset,
  input  uint1  vsync,
  output uint1  fbuffer
) <autorun> {

  sdram_byte_io sdh;
  sdram_half_speed_access sdram_slower<@sdram_clock,!sdram_reset>(
    sd  <:> sd,
    sdh <:> sdh
  );

  uint16 shift = 0;
  uint1  vsync_filtered = 0;
  
  subroutine clear(
    readwrites sdh,
    input   uint1 buffer
  ) {
    uint9 pix_x   = 0;
    uint8 pix_y   = 0;
    uint8 pix_palidx = 0;
    	
    pix_y = 0;  
    while (pix_y < 200) {
      pix_x  = 0;
      while (pix_x < 320) {		
        // write to sdram
        while (1) {          
          if (sdh.busy == 0) {        // not busy?
            sdh.data_in    = pix_palidx;
            sdh.addr       = {1b0,buffer,24b0} | (pix_x) | (pix_y << 9);             
            sdh.in_valid   = 1; // go ahead!
            break;
          }
        }		
        pix_x = pix_x + 1;
      }
      pix_y = pix_y + 1;
    }
    return;
  }

  subroutine bands(
    reads   shift,
    readwrites sdh,
    input   uint1 buffer
  ) {
    uint9 pix_x   = 0;
    uint8 pix_y   = 0;
    uint8 pix_palidx = 0;

    pix_y = 0;  
    while (pix_y < 200) {
      pix_x  = 0;
      while (pix_x < 320) {

        pix_palidx = pix_x + pix_y + shift;
        // write to sdram
        while (1) {
          if (sdh.busy == 0) {        // not busy?
            sdh.addr       = {1b0,buffer,24b0} | (pix_x) | (pix_y << 9); 
            sdh.data_in    = pix_palidx;
            sdh.in_valid = 1; // go ahead!
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

  leds := 0;

  sdh.in_valid   := 0; // maintain low (pulses high when needed)
  sdh.rw         := 1; // always writes

  // clear SDRAM buffers
  () <- clear <- (0);
  () <- clear <- (1);
  () <- bands <- (0);
  () <- bands <- (1);

  while (1) {

    // draw a frame
    () <- bands <- (~fbuffer);
  
    // increment shift    
    shift = (shift >= 320) ? 0 : shift+1;
    
    // wait for frame to end
    while (vsync_filtered == 0) {}

    // swap buffers
    fbuffer = ~fbuffer;

  }
}

// ------------------------- 
