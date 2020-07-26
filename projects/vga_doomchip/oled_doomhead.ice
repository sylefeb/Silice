// SL 2020-05

$$SSD1351=1
$include('../common/oled.ice')

// ------------------------- 

$$dofile('pre_do_doomhead.lua')

// ------------------------- 

algorithm oled_doomhead(
  output uint1  oled_din,
  output uint1  oled_clk,
  output uint1  oled_cs,
  output uint1  oled_dc,
  output uint1  oled_rst,  
) {

  // write down the code for the doomhead data
  $doomhead$
  // palette
  uint18 palette[256] = {
$$  for i=1,256 do
    18h$string.format("%05x",palette_666[i]):sub(-5)$,
$$  end
  };

  uint3  frame = 0;
  uint3  count = 0;
  uint32 nfo   = 0;
  
  uint12 rand = 3137;

  oledio io;
  oled   display(
    oled_din :> oled_din,
    oled_clk :> oled_clk,
    oled_cs  :> oled_cs,
    oled_dc  :> oled_dc,
    oled_rst :> oled_rst,
    io      <:> io
  );

  // maintain low (pulses high when sending)
  io.start_rect := 0;
  io.next_pixel := 0;

  while (1) {
  
    uint8  u     = uninitialized;
    uint8  v     = uninitialized;

    // wait for controller to be ready  
    while (io.ready == 0) { }  
    
    // draw frame
    nfo           = doomface_nfo[frame];
    io.x_start    = 0;
    io.x_end      = (nfo[16,8]<<2)-1;
    io.y_start    = 0;
    io.y_end      = (nfo[24,8]<<2)-1;
    io.start_rect = 1;
    while (io.ready == 0) { } 

    doomhead.addr = nfo[0,16];
    v = 0;
    while (v < nfo[24,8]) {
      uint4  repeat = uninitialized;
      uint16 ptr    = uninitialized;
      repeat = 0;
      ptr    = doomhead.addr;
      while (repeat < 4) { // draw line four times
        u = 0;
        doomhead.addr = ptr;
        while (u < nfo[16,8]) {
          // send pixel x4
          io.color      = palette[doomhead.rdata];
          io.next_pixel = 1;
          while (io.ready == 0) { } 
          
          io.next_pixel = 1;
          while (io.ready == 0) { } 
          
          io.next_pixel = 1;
          while (io.ready == 0) { } 
          
          io.next_pixel = 1;
          while (io.ready == 0) { } 
          
          u = u + 1;
          doomhead.addr = doomhead.addr + 1;      
        }
        repeat = repeat + 1;
      }
      v = v + 1;
    }

    if ((count&7) == 0) {
      rand  = rand * 31421 + 6927;
      if (rand < 2048) {
        frame = 0;
      } else {
        if (rand < $2048+1024$) {
          frame = 1;
        } else {
          frame = 2;
        }
      }
    }
    count = count + 1;
    
  }
  
}

// ------------------------- 
