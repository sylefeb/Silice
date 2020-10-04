// SL 2020-04-28
// DoomChip, VGA wrapper
//
// NOTE: there is tearing currently (unrestricted frame rate),
//       will be fixed later
//

$$if ULX3S then
$$  HAS_COMPUTE_CLOCK    = true
$$  -- ULX3S_SLOW       = true -- uncomment for 25 MHz version
$$  -- sdramctrl_clock_freq = 50 -- DO NOT USE, something is wrong with it, corrupts SDRAM
$$elseif DE10NANO and YOSYS then
$$  -- HAS_COMPUTE_CLOCK    = true
$$elseif SIMULATION then
$$  HAS_COMPUTE_CLOCK    = true
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
//include('doomchip_debug_placeholder.ice')

$$texfile_palette = palette_666
$include('../common/video_sdram_main.ice')

// -------------------------

$$print('------<  VGA mode  >------')

// -------------------------

$include('sdram_column_writer.ice')

// -------------------------
// Main drawing algorithm

algorithm frame_drawer(
  sdio sd {
    output addr,
    output rw,
    output data_in,
    output in_valid,
    input  data_out,
    input  busy,
    input  out_valid,
  },
$$if HAS_COMPUTE_CLOCK then  
  input  uint1  sdram_clock,
  input  uint1  sdram_reset,
$$end  
  input  uint1  vsync,
  output uint1  fbuffer,
$$if DE10NANO then  
  output uint4  kpadC,
  input  uint4  kpadR,
  output uint1  lcd_rs,
  output uint1  lcd_rw,
  output uint1  lcd_e,
  output uint8  lcd_d,
  output uint1  oled_din,
  output uint1  oled_clk,
  output uint1  oled_cs,
  output uint1  oled_dc,
  output uint1  oled_rst,
$$end
$$if ULX3S then
  input  uint7 btns,
$$end  
  output uint8 leds,
) 
$$if HAS_COMPUTE_CLOCK then
<autorun> 
$$end
{
  column_io colio;
  
  doomchip doom( 
    colio <:> colio,
    vsync <: vsync,
    <:auto:> // used to bind parameters across the different boards
  );

$$if HAS_COMPUTE_CLOCK then
  sdram_column_writer writer<@sdram_clock,!sdram_reset>(
$$else
  sdram_column_writer writer(
$$end
    colio   <:> colio,
    sd      <:> sd,
    fbuffer  :> fbuffer,
  );
  
  while (1) { }
  
}
