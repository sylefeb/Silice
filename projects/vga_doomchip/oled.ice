// SL 2020-05
// ------------------------- 
// OLED 128x128 RGB screen driver (SSD1351)
// ------------------------- 

group oledio {
  uint8  x_start = 0,
  uint8  x_end   = 0,
  uint8  y_start = 0,
  uint8  y_end   = 0,
  uint18 color       = 0,
  uint1  start_rect  = 0,
  uint1  next_pixel  = 0,
  uint1  ready   = 0 
}

algorithm oled_pll(
  input   uint1 sys_clock,
  output! uint1 oled_clock
) <autorun>
{
  uint16 counter = 0;
  
  // generate a slower clock
  oled_clock := counter[8,1];
  
  while (1) {
	  counter = counter + 1;
  }
}

algorithm oled(
  output uint1 oled_din,
  output uint1 oled_clk,
  output uint1 oled_cs,
  output uint1 oled_dc,
  output uint1 oled_rst,
  output uint8 led,
  oledio io {
    input  x_start,
    input  x_end,
    input  y_start,
    input  y_end,
    input  color,
    input  start_rect,
    input  next_pixel,
    output ready
  }
) <autorun> {

  oled_pll pll(
    sys_clock <: clock,
    oled_clock :> oled_clk
  );
  
  subroutine wait(input uint24 delay)
  {
    uint24 count = 0;
    while (count < delay) {
      count = count + 1;
    }   
  }

  subroutine synch_clk(input uint1 state,reads oled_clk)
  {
    while (oled_clk != state) { }
  }
  
  subroutine send(
    input  uint8 byte,
    input  uint1 data_or_command,
    reads  oled_clk,
    writes oled_din,
    writes oled_cs,
    writes oled_dc,
    calls synch_clk
    )
  {
    uint8  b = 0;
    uint4  n = 0;
    b        = byte;
    // wait for oled clock to be low
    () <- synch_clk <- (0);
    // prepare for sending
    oled_cs  = 0;
    oled_dc  = data_or_command;
    while (n < 8) {
      // send next bit
      oled_din = b[7,1];
      b        = {b[0,7],1b0};
      n        = n + 1;
      // wait for oled clock to raise
      () <- synch_clk <- (1);
      // wait for oled clock to be low
      () <- synch_clk <- (0);
    }
    oled_cs  = 1;
    () <- synch_clk <- (1);
    () <- synch_clk <- (0);
  }

  uint8 n = 0;
  uint28 debug = 0;
  
  led[0,1] := oled_clk;
  led[1,1] := 1;
  led[2,1] := debug[27,1];
  led[7,1] := io.ready;
  
  //---------------
  // Intializing
  //---------------

  io.ready = 0;
  
  () <- synch_clk <- (0);
  // reset high
  oled_rst = 1;
  // cs high
  oled_cs  = 1;
  () <- synch_clk <- (1);
  
  // 100 msec @100Mhz
  n = 0;
  while (n < 10) {
    () <- wait <- (1000000); // 10 msec @100Mhz
    n = n + 1;
  }
  
  // reset low
  () <- synch_clk <- (0);
  oled_rst = 0;
  () <- synch_clk <- (1);
  
  // wait some
  () <- wait <- (300);  // 3 usec @100Mhz  
  
  // reset high
  () <- synch_clk <- (0);
  oled_rst = 1;
  () <- synch_clk <- (1);
  
  // 300 msec @100Mhz
  n = 0;
  while (n < 30) {
    () <- wait <- (1000000);
    n = n + 1;
  }

  // send screen-on command
  () <- send <- (8haf,0);

  // 300 msec @100Mhz
  n = 0;
  while (n < 30) {
    () <- wait <- (1000000);
    n = n + 1;
  }

  // select auto horiz. increment, 666 RGB 
  () <- send <- (8ha0,0);
  () <- send <- (8b10100000,1);

  // unlock
  () <- send <- (8hfd,0);
  () <- send <- (8hb1,1);

  // set verticfal scroll to 0
  () <- send <- (8ha2,0);
  () <- send <- (8h00,1);

  // send all gray command  
  //() <- send <- (8ha5,0);
  
  //---------------
  // Init done!
  //--------------  

  //////////// TEST
  // set col addr
  () <- send <- (8h15,0);
  () <- send <- (  0,1);
  () <- send <- (127,1);
  // set row addr
  () <- send <- (8h75,0);
  () <- send <- (  0,1);
  () <- send <- (127,1);
  // initiate write
  () <- send <- (8h5c,0); 
  {
    uint8 u = 0;
    uint8 v = 0;
    v = 0;
    while (v < 128) {
      u = 0;    
      while (u < 128) {
        u = u + 1;
        () <- send <- (u,1); // b
        () <- send <- (v,1); // g
        () <- send <- (8hff,1); // r
      }
      v = v + 1;
    }   
  }

  
  while (1) {

    io.ready = 1;

    debug = debug + 1;

    if (io.start_rect) {
      led[4,1] = 1;
      io.ready = 0;
      // set col addr
      () <- send <- (8h15,0);
      () <- send <- (io.x_start,1);
      () <- send <- (io.x_end,1);
      // set row addr
      () <- send <- (8h75,0);
      () <- send <- (io.y_start,1);
      () <- send <- (io.y_end,1);
      // initiate write
      () <- send <- (8h5c,0);
    }

    if (io.next_pixel) {
      led[3,1] = 1;
      io.ready = 0;
      // send pixel
      () <- send <- (io.color[12,6],1);
      () <- send <- (io.color[ 6,6],1);
      () <- send <- (io.color[ 0,6],1);
    }
    
  }

}

// ------------------------- 
