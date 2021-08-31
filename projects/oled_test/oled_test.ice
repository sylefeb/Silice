// SL 2020-07
// MIT license, see LICENSE_MIT in Silice repo root

// vvvvvvvvvvvvv select screen driver below
$$ -- SSD1331=1
$$ -- SSD1351=1
$$ ST7789=1
//               vvvvv adjust to your screen
$$ oled_width   = 240
$$ oled_height  = 240
//               vvvvv set to false if the screen uses the CS pin
$$ st7789_no_cs = true
//                   vvvvv set to true to rotate view 90 degrees
$$ st7789_transpose = true

// ------------------------- 

$include('../common/oled.ice')

$$if not OLED then
$$error('This project requires an OLED screen')
$$end

// ------------------------- 

algorithm main(
  output uint$NUM_LEDS$ leds,
  output uint1 oled_clk,
  output uint1 oled_mosi,
  output uint1 oled_dc,
  output uint1 oled_resn,
  output uint1 oled_csn,
) {

  oledio io;
  oled   display(
    oled_clk  :> oled_clk,
    oled_mosi :> oled_mosi,
    oled_dc   :> oled_dc,
    oled_resn :> oled_resn,
    oled_csn  :> oled_csn,
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
