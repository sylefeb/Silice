// ------------------------- 

// debug palette
$$palette = {}
$$for i=0,255 do
$$  palette[1+i] = (i) | (((i<<1)&255)<<8) | (((i<<2)&255)<<16)
$$end

$$mode_640_480 = true

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
    uint10 pix_x   = 0;
    uint9  pix_y   = 0;
    uint8  pix_palidx = 0;
    	
    pix_y = 0;  
    while (pix_y < 480) {
      pix_x  = 0;
      while (pix_x < 640) {		
        // write to sdram
        sdh.data_in    = pix_palidx;
        sdh.addr       = {1b0,buffer,24b0} | (pix_x) | (pix_y << 10);             
        sdh.in_valid   = 1; // go ahead!
        while (!sdh.done) { }
        pix_x = pix_x + 1;
      }
      pix_y = pix_y + 1;
    }
  }

  subroutine bands(
    reads   shift,
    readwrites sdh,
    input   uint1 buffer
  ) {
    uint10 pix_x   = 0;
    uint9 pix_y   = 0;
    uint8 pix_palidx = 0;

    pix_y = 0;  
    while (pix_y < 480) {
      pix_x  = 0;
      while (pix_x < 640) {

        pix_palidx     = (pix_y == 0 || pix_y == 479) ? 255 : (pix_x + pix_y + shift);
        // write to sdram
        sdh.addr       = {1b0,buffer,24b0} | (pix_x) | (pix_y << 10); 
        sdh.data_in    = pix_palidx;
        sdh.in_valid = 1; // go ahead!
        while (!sdh.done) { }

        pix_x = pix_x + 1;
      }
      pix_y = pix_y + 1;
    }
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
    shift = (shift >= 640) ? 0 : shift+1;
    
    // wait for frame to end
    while (vsync_filtered == 0) {}

    // swap buffers
    fbuffer = ~fbuffer;

  }
}

// ------------------------- 
