// SL 2020-05
// ------------------------- 
// OLED 128x128 RGB screen driver (SSD1351)
// ------------------------- 

group oledio {
  uint1 ready = 0  
}

algorithm oled(
  output uint1 oled_din,
  output uint1 oled_clk,
  output uint1 oled_cs,
  output uint1 oled_dc,
  output uint1 oled_rst,
  oledio io {
    output ready
  }
) <autorun> {

  subroutine wait(input uint24 delay)
  {
    uint24 count = 0;
    while (count < delay) {
      count = count + 1;
    }   
  }
  
  subroutine send(
    input  uint8 byte,
    input  uint1 data_or_command,
    writes oled_clk,
    writes oled_din,
    writes oled_cs,
    writes oled_dc,
    calls wait
    )
  {
    uint8  b = 0;
    uint4  n = 0;
    oled_clk = 0;
    oled_cs  = 0;
    oled_dc  = data_or_command;
    b        = byte;
    // wait half
    () <- wait <- (6);
    while (n < 8) {
      // prepare data
      oled_din = b[7,1];
      b        = {b[0,7],1b0};
      n        = n + 1;
      // wait half
      () <- wait <- (6);
      // raise clock
      oled_clk = 1; 
      // wait full
      () <- wait <- (12);
      // lower clock
      oled_clk = 0;
      // wait half
      () <- wait <- (6);
    }
    oled_cs  = 1;
  }

  uint8 n = 0;
  
  //---------------
  // Intializing
  //---------------

  io.ready = 0;
  
  // reset high
  oled_rst = 1;
  // 100 msec @100Mhz
  n = 0;
  while (n < 10) {
    () <- wait <- (1000000); // 10 msec @100Mhz
    n = n + 1;
  }
  // reset low
  oled_rst = 0;
  // wait some
  () <- wait <- (300);  // 3 usec @100Mhz  
  // reset high
  oled_rst = 1;
  
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

  // send all gray command  
  () <- send <- (8ha5,0);

  
  //---------------
  // Init done!
  //--------------  

  io.ready = 1;
  
  while (1) {
    
  }
  
}

// ------------------------- 
