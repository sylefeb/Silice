// SL 2020-04-28
// DoomChip, OLED wrapper


$$if ULX3S then
// vvvvvvvvvvvvv select screen driver below
$$ -- SSD1331=1
$$ -- SSD1351=1
$$ ST7789=1
//               vvvvv adjust to your screen
$$ oled_width   = 240
$$ oled_height  = 240
//               vvvvv set to false if the screen uses the CS pin
$$ st7789_no_cs = true
$include('../common/oled.ice')
$$elseif ICARUS then
$$  ST7789=1
$include('../common/oled.ice')
$$elseif VERILATOR then
$$  ST7789=1
$include('../common/oled.ice')
$$else
$$  error('OLED doomchip only tested on ULX3S')
$$end

$$color_depth = 6
$$color_max   = 63

// -------------------------

group column_io {
  uint10 draw_col  = 0, // column that can be drawn
                        // (drawer should not draw beyond this)
  uint10 y        = 0,
  uint8  palidx   = 0,
  uint1  write    = 0,
  uint1  done     = 0,
}

$$doomchip_width  = oled_height
$$doomchip_height = oled_width

$$doomchip_vflip  = true

$include('doomchip.ice')
// include('doomchip_debug_placeholder.ice')

// -------------------------

$$print('------< OLED mode >------')

// -------------------------

$$if ULX3S then
import('ulx3s_clk_50_25_100.v')
$$end

// ------------------------- 

$$if ICARUS or VERILATOR then
// PLL for simulation
algorithm pll(
  output! uint1 oled_clock,
  output! uint1 compute_clock,
) <autorun>
{
  uint3 counter = 0;
  
  oled_clock    := clock;
  compute_clock := counter[1,1]; // x4 slower
  
  while (1) {	  
    counter = counter + 1;
  }
}
$$end

// -------------------------

algorithm oled_pixel_writer(
  column_io colio {
    output  draw_col,
    input   y,
    input   palidx,
    input   write,
    input   done,
  },
  oledio displio {
    output  x_start,
    output  x_end,
    output  y_start,
    output  y_end,
    output  color,
    output  start_rect,
    output  next_pixel,
    input   ready
  },
) <autorun> {
  
  uint$3*color_depth$ palette[] = {
$$if palette_666 then
$$  for i=1,256 do
    $palette_666[i]$,
$$  end
$$else
$$    for i=0,256/4-1 do
        $math.floor(i*color_max/(256/4-1))$,
$$    end
$$    for i=0,256/4-1 do
        $math.floor(lshift(i*color_max/(256/4-1),color_depth))$,
$$    end  
$$    for i=0,256/4-1 do
        $math.floor(lshift(i*color_max/(256/4-1),2*color_depth))$,
$$    end
$$    for i=0,256/4-1 do v = i*color_max/(256/4-1)
        $math.floor(v + lshift(v,color_depth) + lshift(v,2*color_depth))$,
$$    end
$$end
  };
    
  simple_dualport_bram uint8 col_buffer[$doomchip_height*2$] = uninitialized;
  uint10 drawer_offset = 0; // offset of column being drawn
  uint10 xfer_offset   = $doomchip_height$; // offset of column being transfered
  uint10 xfer_count    = $doomchip_height$; // transfer count
  uint10 xfer_col      = $doomchip_width-1$; // column being transfered
  uint10 last_drawn    = -1;
  uint10 draw_col      = 0;
  uint1  done          = 0;
  
  col_buffer.wenable1 := 1; // write on port1, read on port0
  // column that can be drawn
  colio.draw_col      := draw_col;
  // maintain low, pulses high
  displio.start_rect  := 0;
  displio.next_pixel  := 0;
  
  always {
    if (colio.write) {
      // write in bram
      col_buffer.addr1  = drawer_offset + colio.y;
      col_buffer.wdata1 = colio.palidx;
    }
    if (colio.done && (last_drawn != draw_col)) {
      last_drawn = draw_col;
      // __display("done received (draw_col: %d)",draw_col);
      done = 1;
    }   
  }
  
  // prepare viewport
  while (displio.ready == 0) { }
  displio.x_start    = 0;
  displio.x_end      = $oled_width-1$;
  displio.y_start    = 0;
  displio.y_end      = $oled_height-1$;
  displio.start_rect = 1;
  
  while (1) {
    // continue with transfer if not done
    if (xfer_count < $doomchip_height$) {
      // write
      while (displio.ready == 0) { }
      displio.color      = palette[col_buffer.rdata0];
      displio.next_pixel = 1;
      // next      
      xfer_count      = xfer_count + 1;
      if (xfer_count < $doomchip_height$) {
        col_buffer.addr0 = xfer_offset + xfer_count;
      } else {
        // done
        // __display("xfer %d done (count %d)",xfer_col,xfer_count);
        xfer_col         = (draw_col == 0) ? 0 : xfer_col+1;
        draw_col         = (draw_col == $doomchip_width$) ? 0 : draw_col+1; 
        xfer_offset      = (xfer_offset   == 0) ? $doomchip_height$ : 0;
        drawer_offset    = (drawer_offset == 0) ? $doomchip_height$ : 0;
        col_buffer.addr0 = xfer_offset; // position for restart        
        if (draw_col == $doomchip_width$) {
          // frame done
          draw_col = 0;
        }
        // __display("next: xfer %d, draw %d",xfer_col,draw_col);
      }
    } else {    
      if (done) {
        done = 0;
        // __display("column %d drawn",draw_col);
        // __display(" -> starting xfer %d",xfer_col);
        // starts xfer
        xfer_count    = 0; 
      }    
    }
  }
}

// -------------------------
// Main

algorithm main(
  output  uint8 leds,
  input   uint7 btns,
  output  uint1 oled_clk,
  output  uint1 oled_mosi,
  output  uint1 oled_dc,
  output  uint1 oled_resn,
  output  uint1 oled_csn,  
  output  uint1 sd_clk,
  output  uint1 sd_mosi,
  output  uint1 sd_csn,
  input   uint1 sd_miso  
) <@compute_clock> {

  column_io colio;
  
  uint1  vsync = 1;
$$if SIMULATION then
  uint32 iter  = 0;
$$end

  // clocking  
$$if ULX3S then
  uint1 oled_clock    = 0;
  uint1 compute_clock = 0;
  uint1 unused_clock    = 0;
  uint1 pll_lock      = 0;
  ulx3s_clk_50_25_100 clk_gen(
    clkin    <: clock,
    clkout0  :> compute_clock, // unused_clock,
    clkout1  :> unused_clock,  // compute_clock,
    clkout2  :> oled_clock,
    locked   :> pll_lock
  ); 
$$end
$$if SIMULATION then
  uint1 oled_clock    = 0;
  uint1 compute_clock = 0;
  pll clk_gen<@clock>(
    oled_clock    :> oled_clock,
    compute_clock :> compute_clock,
  );   
$$end

  doomchip doom( 
    colio <:> colio,
    vsync <: vsync,
    <:auto:> // used to bind parameters across the different boards
  );

  oledio displio;

  oled   display<@oled_clock>(
    oled_clk  :> oled_clk,
    oled_mosi :> oled_mosi,
    oled_dc   :> oled_dc,
    oled_resn :> oled_resn,
    oled_csn  :> oled_csn,
    io       <:> displio
  );

  oled_pixel_writer writer(
    colio   <:> colio,
    displio <:> displio,
  );
   
$$if SIMULATION then
  while (iter < 4000000) { iter = iter + 1; }
$$else
  while (1) { }
$$end
}
