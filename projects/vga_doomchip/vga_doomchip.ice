// SL 2020-04-24
// Wolf3D!
//
// References:
// "DooM black book" by Fabien Sanglard
// DooM unofficial specs http://www.gamers.org/dhs/helpdocs/dmsp1666.html

$$print('main file')
$$texfile = 'doom.tga'
$$texfile_palette = get_palette_as_table(texfile,color_depth)

$include('../common/video_sdram_main.ice')

$$FPw = 30
$$FPf = 12 -- fractions precision
$$FPm = 12 -- precision within cells

$$div_width = FPw
$include('../common/divint_any.ice')

$$dofile('pre_load_data.lua')
$$dofile('pre_render_test.lua')

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

  uint1  vsync_filtered = 0;

  div$FPw$ div;
  
  uint9 c = 0;
  
  vsync_filtered ::= vsync;

  sin_valid := 0; // maintain low (pulses high when needed)
  
  srw = 1;        // sdram write

  fbuffer = 0;
  
  while (1) {

    // raycast columns
    c = 0;
    while (c < 320) { 
      
      c = c + 1;
    }
    
    // draw columns
    
    // wait for frame to end
    while (vsync_filtered == 0) {}

    // swap buffers
    fbuffer = ~fbuffer;

  }

}

// ------------------------- 
