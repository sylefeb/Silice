// SL 2020-08 @sylefeb

// Select screen driver below
$$ -- SSD1351=1
$$ ST7789=1
$include('../common/oled.ice')

$$if not ULX3S and not ICARUS then
$$error('only tested on ULX3S, small changes likely required to main input/outputs for other boards')
$$end

// ------------------------- 

$include('../common/sdcard.ice')
$include('../common/sdcard_streamer.ice')
$$dofile('pre_sdcard_image.lua')

// ------------------------- 

algorithm main(
  output! uint8 leds,
  input   uint7 btn,
  output! uint1 oled_clk,
  output! uint1 oled_mosi,
  output! uint1 oled_dc,
  output! uint1 oled_resn,
  output! uint1 oled_csn,
  output! uint1 sd_clk,
  output! uint1 sd_mosi,
  output! uint1 sd_csn,
  input   uint1 sd_miso
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

  streamio stream;
  sdcard_streamer streamer(
    sd_clk  :> sd_clk,
    sd_mosi :> sd_mosi,
    sd_csn  :> sd_csn,
    sd_miso <: sd_miso,
    stream  <:> stream
  );

  // Buffers with image data
  bram uint18 palette[256]                    = uninitialized;
  bram uint8  image[$oled_width*oled_height$] = uninitialized;

  uint7  btn_latch = 0;

  btn_latch     := btn;

  // maintain low (pulses high when needed)
  io.start_rect := 0;
  io.next_pixel := 0;
  stream.next   := 0;

leds = 0;

  // wait for oled controller to be ready  
  while (io.ready == 0) { }

leds = 2;

  // wait for sdcard controller to be ready  
  while (stream.ready == 0)    { }

leds = 4;

  // read palette
  {
    uint10 to_read  = 0;
    palette.wenable = 1;    
    palette.addr    = 0;
    while (to_read < 256) {    
      uint18 clr = 0;
      uint6 n    = 0;
      n = 0;
      while (n < 18) {
        stream.next = 1;
        while (stream.ready == 0) { }
        clr[   n,6] = stream.data[2,6];
        n           = n + 6;
      }      
      palette.addr  = to_read;
      palette.wdata = clr;
      to_read       = to_read + 1;
    }
    palette.wenable = 0;
  }

leds = 8;

  // read image
  {
    uint17 to_read = 0;
    image.wenable  = 1;    
    while (to_read < $oled_width*oled_height$) {    
      leds         = to_read;
      stream.next  = 1;
      while (stream.ready == 0) { }
      image.wdata  = stream.data;
      image.addr   = to_read;
      to_read      = to_read + 1;
    }
    image.wenable = 0;  
  }

leds = 16;

  while (1)
  {
    uint10 v   = 0;

    // setup draw window
    io.x_start = 0;
    io.x_end   = $oled_width-1$;
    io.y_start = 0;
    io.y_end   = $oled_height-1$;
    io.start_rect = 1;
    while (io.ready == 0) { }

    // refresh
    image.addr = 0;
    while (v < $oled_height$) {
      uint10 u = 0;
      while (u < $oled_width$) {
        palette.addr  = image.rdata;
++:        
        io.color      = palette.rdata;
        io.next_pixel = 1;
        while (io.ready == 0) { }        
        image.addr = image.addr + 1;        
        u = u + 1;
      }
      v = v + 1;
    }        
  }

}

// ------------------------- 
