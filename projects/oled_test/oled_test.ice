// SL 2020-07

// Select screen driver below
$$ -- SSD1351=1
$$ ST7789=1
$include('../common/oled.ice')

$$if not ULX3S and not DE10NANO and not ICARUS then
$$error('only tested on ULX3S and DE10NANO, small changes likely required to main input/outputs for other boards')
$$end

// ------------------------- 

algorithm main(
  output! uint$NUM_LEDS$ leds,
$$if ULX3S then
  input   uint7 btn,
  output! uint1 oled_clk,
  output! uint1 oled_mosi,
  output! uint1 oled_dc,
  output! uint1 oled_resn,
  output! uint1 oled_csn,
$$end
$$if ICARUS then
  input   uint7 btn,
  output! uint1 oled_clk,
  output! uint1 oled_mosi,
  output! uint1 oled_dc,
  output! uint1 oled_resn,
  output! uint1 oled_csn,
$$end
$$if DE10NANO then
  output! uint4 kpadC,
  input   uint4 kpadR,
  output! uint1 lcd_rs,
  output! uint1 lcd_rw,
  output! uint1 lcd_e,
  output! uint8 lcd_d,
  output! uint1 oled_din,
  output! uint1 oled_clk,
  output! uint1 oled_cs,
  output! uint1 oled_dc,
  output! uint1 oled_rst,  
  output! uint1  sdram_cle,
  output! uint1  sdram_dqm,
  output! uint1  sdram_cs,
  output! uint1  sdram_we,
  output! uint1  sdram_cas,
  output! uint1  sdram_ras,
  output! uint2  sdram_ba,
  output! uint13 sdram_a,
  output! uint1  sdram_clk,
  inout   uint8  sdram_dq,
  output! uint$color_depth$ video_r,
  output! uint$color_depth$ video_g,
  output! uint$color_depth$ video_b,
  output! uint1 video_hs,
  output! uint1 video_vs
$$end
) {

  oledio io;
  oled   display(
$$if ULX3S then
    oled_clk  :> oled_clk,
    oled_mosi :> oled_mosi,
    oled_dc   :> oled_dc,
    oled_resn :> oled_resn,
    oled_csn  :> oled_csn,
$$end
$$if DE10NANO then
    oled_clk  :> oled_clk,
    oled_mosi :> oled_din,
    oled_dc   :> oled_dc,
    oled_resn :> oled_rst,
    oled_csn  :> oled_cs,
$$end
    io       <:> io
  );

  uint16 frame = 0;

  leds := frame[0,8];

  // maintain low (pulses high when sending)
  io.start_rect := 0;
  io.next_pixel := 0;
  
  while (1) {
  
    uint10 u     = uninitialized;
    uint10 v     = uninitialized;

    // wait for controller to be ready  
    while (io.ready == 0) { }

     // draw window
    io.x_start = 0;
    io.x_end   = $oled_width-1$;
    io.y_start = 0;
    io.y_end   = $oled_height-1$;
    io.start_rect = 1;
    while (io.ready == 0) { }

    // simple test pattern
    v = 0;
    while (v < $oled_height$) {
      u = 0;
      while (u < $oled_width$) {
        uint18 tmp    = uninitialized;
        tmp           = u + v + frame;
        io.color      = tmp;
        io.next_pixel = 1;
        while (io.ready == 0) { } // wait ack
        u = u + 1;
      }
      v = v + 1;
    }
    
    frame = frame + 1;
   
  }

}

// ------------------------- 
