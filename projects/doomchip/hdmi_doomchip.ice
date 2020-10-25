// SL 2020-04-28
// DoomChip, HDMI wrapper
//
// NOTE: there is tearing currently (unrestricted frame rate),
//       will be fixed later
//

$$if ULX3S then
$$  HAS_COMPUTE_CLOCK    = true
$$else
$$  error('only tested on ULX3S, other boards will require changes')
$$end
 
// -------------------------

group column_io {
  uint10 draw_col  = 0, // column that can be drawn
                        // (drawer should not draw beyond this)
  uint10 y         = 0,
  uint8  palidx    = 0,
  uint1  write     = 0, // pulse high to draw column pixel
  uint1  done      = 0, // done drawing column
}

$$doomchip_width  = 320 
$$doomchip_height = 200

$include('doomchip.ice')
// include('doomchip_debug_placeholder.ice')

$$texfile_palette = palette_666
$include('../common/video_sdram_main.ice')

// -------------------------

$$print('------<  HDMI mode  >------')

// -------------------------

$include('sdram_column_writer.ice')

// -------------------------
// Main drawing algorithm

algorithm frame_drawer(
  sdram_user    sd,
  input  uint1  sdram_clock,
  input  uint1  sdram_reset,
  input  uint1  vsync,
  output uint1  fbuffer,
$$if ULX3S or DE10NANO then
  input  uint7  btns,
$$end
  output uint8  leds,
) <autorun> {

  column_io colio;  
  doomchip doom( 
    colio <:> colio,
    vsync <: vsync,
    <:auto:> // used to bind parameters across the different boards
  );

  sdram_byte_io sdh;
  sdram_half_speed_access half<@sdram_clock,!sdram_reset>(
    sd  <:> sd,
    sdh <:> sdh
  );

  sdram_column_writer writer(
    colio   <:> colio,
    sd      <:> sdh,
    fbuffer  :> fbuffer,
  );
  
  while (1) { }
  
}
