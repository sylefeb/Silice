
$include('../common/divint16.ice')
$include('../common/vga_sdram_main_mojo.ice')

// ------------------------- 

algorithm frame_drawer(
  output uint23 saddr,
  output uint2  swbyte_saddr,
  output uint1  srw,
  output uint32 sdata_in,
  output uint1  sin_valid,
  input  uint32 sdata_out,
  input  uint1  sbusy,
  input  uint1  sout_valid,
  input  uint1  vsync
) {

  uint1  vsync_filtered = 0;

  
  
  vsync_filtered ::= vsync;

  sin_valid      := 0; // maintain low (pulses high when needed)

  srw   = 1;  // write

  while (1) {

    // draw
    // () <- draw_quad <- ();
	
    // wait for vsync
    while (vsync_filtered == 1) {}
    while (vsync_filtered == 0) {}

  }
}

// ------------------------- 
