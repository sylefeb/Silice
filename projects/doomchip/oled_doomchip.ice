// SL 2020-04-28
// DoomChip, VGA wrapper
//

$$if ULX3S then
$$  HAS_COMPUTE_CLOCK = true
$$  ULX3S_25MHZ = true
$$  ST7789=1
$include('../common/oled.ice')
$$elseif ICARUS then
$$  ST7789=1
$include('../common/oled.ice')
$$else
$$  error('OLED doomchip only tested on ULX3S')
$$end

$$color_depth=6

// -------------------------

group column_io {
  uint10 draw_col = 0, // column that can be drawn (drawer should not draw beyond this)
  uint10 y        = 0,
  uint8  palidx   = 0,
  uint1  write    = 0,
  uint1  done     = 0,
}

$$doomchip_width  = 240
$$doomchip_height = 240

//$include('doomchip.ice')
$include('doomchip_debug_placeholder.ice')

// -------------------------

$$print('------< OLED mode >------')

// -------------------------

algorithm oled_pixel_writer(
  pixel_io pixio {
    output  busy,
    input   x,
    input   y,
    input   palidx,
    input   write,
  },
  oledio displio {
    output! x_start,
    output! x_end,
    output! y_start,
    output! y_end,
    output! color,
    output! start_rect,
    output! next_pixel,
    input   ready
  },
) <autorun> {
  
  uint$3*color_depth$ palette[] = {
$$  for i=1,256 do
    $palette_666[i]$,
$$  end
  };
  
  bram uint8 col_buffer[$doomchip_height$] = uninitialized;
  uint10 last_col = 0;
  
  pixel_io buffered;  
  
  always {
    if (pixio.write) {
      // latch pixel to be written
      buffered.x      = pixio.x;
      buffered.y      = pixio.y;
      buffered.palidx = pixio.palidx;
      buffered.write  = 1;
    }
    pixio.busy = buffered.write;
  }
  
  displio.x_start    = 0;
  displio.x_end      = $doomchip_width-1$;
  displio.y_start    = 0;
  displio.y_end      = $doomchip_height-1$;
  displio.start_rect = 1;
  while (displio.ready == 0) { }

  while (1) {
    if (buffered.write == 1) {
      if (last_col != buffered.x) {
        // output column to oled
        uint10 i = 0;
        col_buffer.wenable = 0;
        col_buffer.addr    = i;
        while (i < $doomchip_height$) {
          // wait oled to be available
          while (displio.ready == 0) { }
          // write pixel
          displio.color = palette[col_buffer.rdata];
          i = i + 1;
          col_buffer.addr = i;
        }
        // done
      }
      // write to buffer
      last_col           = buffered.x;
      col_buffer.addr    = buffered.y;
      col_buffer.wenable = 1;
      col_buffer.wdata   = buffered.palidx;
      // done
      buffered.write = 0;
    }
  }
  
}

// -------------------------
// Main drawing algorithm

algorithm main(
  output! uint8 led,
  input   uint7 btn,
  output! uint1 oled_clk,
  output! uint1 oled_mosi,
  output! uint1 oled_dc,
  output! uint1 oled_resn,
  output! uint1 oled_csn,  
) {

  pixel_io pixio;
  
  uint1 vsync = 1;
  
  doomchip doom( 
    pixio <:> pixio,
    vsync <: vsync,
    <:auto:> // used to bind parameters across the different boards
  );

  oledio displio;
  
  oled   display(
    oled_clk  :> oled_clk,
    oled_mosi :> oled_mosi,
    oled_dc   :> oled_dc,
    oled_resn :> oled_resn,
    oled_csn  :> oled_csn,
    io       <:> displio
  );
  
  oled_pixel_writer writer(
    pixio   <:> pixio,
    displio <:> displio,
  );
  
  while (1) {  }
}
