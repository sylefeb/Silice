// SL 2020-08

// Select screen driver below
$$ -- SSD1351=1
$$ ST7789=1
$include('../common/oled.ice')

$$if not ULX3S and not ICARUS then
$$error('only tested on ULX3S, small changes likely required to main input/outputs for other boards')
$$end

// ------------------------- 

$include('sdcard.ice')
$$dofile('pre_sdcard_image.lua')

// ------------------------- 

algorithm sdcard_streamer(
  output! uint1 sd_clk,
  output! uint1 sd_mosi,
  output! uint1 sd_csn,
  input   uint1 sd_miso,
  output  uint8 led,
  input   uint1 next,
  output  uint8 data,
  output  uint1 ready,
) <autorun> {

  // Read buffer
  dualport_bram uint8 sdbuffer[512] = uninitialized;

  // SD-card interface
  uint40 status = 0;
  uint1  read_sector = 0;
  uint32 addr_sector = 0;
  sdcard sd(
    sd_clk  :> sd_clk,
    sd_mosi :> sd_mosi,
    sd_csn  :> sd_csn,
    sd_miso <: sd_miso,
    status  :> status,
    read_sector <: read_sector,
    addr_sector <: addr_sector,
    store_addr  :> sdbuffer.addr1,
    store_byte  :> sdbuffer.wdata1,
    led :> led
  );
  
  // Global pointer in data
  uint32 ptr     = 0;
  uint1  do_next = 0;
  
  sdbuffer.wenable0 := 0;
  sdbuffer.wenable1 := 1;  
  read_sector       := 0;

  always {
    if (next) {
      do_next = 1;
      ready   = 0;
    }
  }

  ready = 0;

  // wait for sdcard to initialize
  while (sd.ready == 0) { }

  ready = 1;

  addr_sector = 0;
  while (1) {
    if (do_next) {
      do_next = 0;
      // read next sector?
      if (ptr[0,9] == 0) {
        read_sector = 1;
        // wait for sdcard
        while (sd.ready == 0) { }
        // prepare for next
        addr_sector = addr_sector + 1;
      }
      sdbuffer.addr0 = ptr[0,9];
++:      
      data           = sdbuffer.rdata0; // ptr;
      ptr            = ptr + 1;
      ready          = 1;
    }
  }
  
}

// ------------------------- 

algorithm main(
  output! uint8 led,
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

  uint1 next  = 0;
  uint8 data  = 0;
  uint1 ready = 0;

  uint8 foo   = 0;

  sdcard_streamer streamer(
    sd_clk  :> sd_clk,
    sd_mosi :> sd_mosi,
    sd_csn  :> sd_csn,
    sd_miso <: sd_miso,
    led     :> foo,
    next    <: next,
    data    :> data,
    ready   :> ready    
  );

  // Buffers with image data
  bram uint18 palette[256]                    = uninitialized;
  bram uint8  image[$oled_width*oled_height$] = uninitialized;

  uint7  btn_latch = 0;

  btn_latch     := btn;

  // maintain low (pulses high when needed)
  io.start_rect := 0;
  io.next_pixel := 0;
  next          := 0;

led = 0;

  // wait for oled controller to be ready  
  while (io.ready == 0) { }

led = 2;

  // wait for sdcard controller to be ready  
  while (ready == 0)    { }

led = 4;

  // fill palette with white DEBUG
  {
    uint10 to_read  = 0;
    palette.wenable = 1;    
    palette.addr    = 0;
    while (to_read < 256) {    
      uint18 clr = 0;
      uint6 n    = 0;
      n = 0;
      while (n < 18) {
        clr[   n,6] = 18h7ffff;
        n           = n + 6;
      }      
      palette.addr  = to_read;
      palette.wdata = clr;
      to_read       = to_read + 1;
    }
    palette.wenable = 0;
  }

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
        next        = 1;
        while (ready == 0) { }
        clr[   n,6] = data[2,6]; // (n == 0) ? to_read[2,6] : 0; //
        n           = n + 6;
      }      
      palette.addr  = to_read;
      palette.wdata = clr;
      to_read       = to_read + 1;
    }
    palette.wenable = 0;
  }

led = 8;

  // read image
  {
    uint17 to_read = 0;
    image.wenable  = 1;    
    while (to_read < $oled_width*oled_height$) {    
      led          = to_read;
      next         = 1;
      while (ready == 0) { }
      image.wdata  = data;
      image.addr   = to_read;
      to_read      = to_read + 1;
    }
    image.wenable = 0;  
  }

led = 16;

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
