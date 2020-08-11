// SL 2020-07
// ------------------------- 
// OLED RGB screen driver (SSD1351)
// ------------------------- 

group oledio {
  uint9  x_start = 0,
  uint9  x_end   = 0,
  uint9  y_start = 0,
  uint9  y_end   = 0,
  uint18 color       = 0,
  uint1  start_rect  = 0,
  uint1  next_pixel  = 0,
  uint1  ready   = 0 
}

// ------------------------- 

$$oled_send_delay = 8*2

algorithm oled_send(
  input!  uint1 enable,
  input!  uint1 data_or_command,
  input!  uint8 byte,
  output  uint1 oled_clk,
  output  uint1 oled_mosi,
  output  uint1 oled_dc,
) <autorun> {

  uint2  osc        = 1;
  uint1  dc         = 0;
  uint9  sending    = 0;
  
  always {
    oled_dc  =  dc;
    osc      =  (sending>1) ? {osc[0,1],osc[1,1]} : 1;
    oled_clk =  (sending>1) && (osc[0,1]); // SPI Mode 0
    if (enable) {
      dc         = data_or_command;
      oled_dc    =  dc;
      sending    = {1b1,
        byte[0,1],byte[1,1],byte[2,1],byte[3,1],
        byte[4,1],byte[5,1],byte[6,1],byte[7,1]};
    } else {
      oled_mosi = sending[0,1];
      if (osc[0,1]) {
        sending   = {1b0,sending[1,8]};
      }
    }
  }
}

// ------------------------- 

algorithm oled(
  output uint1 oled_clk,
  output uint1 oled_mosi,
  output uint1 oled_dc,
  output uint1 oled_resn,
  output uint1 oled_csn,
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

  subroutine wait(input uint32 delay)
  {
    uint32 count = 0;
$$if SIMULATION then
    while (count < $oled_send_delay$) {
$$else
    while (count < delay) { 
$$end
      count = count + 1;
    }   
  }

  uint1 enable          = 0;
  uint1 data_or_command = 0;
  uint8 byte            = 0;
  oled_send sender(
    enable          <:: enable,
    data_or_command <:: data_or_command,
    byte            <:: byte,
    oled_clk  :> oled_clk,
    oled_mosi :> oled_mosi,
    oled_dc   :> oled_dc,
  );  

  subroutine sendCommand(input uint8 val,
    writes enable,writes data_or_command,writes byte,calls wait)
  {
    data_or_command = 0;
    byte            = val;
    enable          = 1;    
    () <- wait <- ($oled_send_delay-4$);
  }

  subroutine sendData(input uint8 val,
    writes enable,writes data_or_command,writes byte,calls wait)
  {
    data_or_command = 1;
    byte            = val;
    enable          = 1;    
    () <- wait <- ($oled_send_delay-4$);
  }
  
  // always enabled
  oled_csn := 0;
  
  //---------------
  // Intializing
  //---------------

  io.ready = 0;
  
  // reset high
  oled_resn = 1;
  () <- wait <- (2500000); // 100 msec @25Mhz  
  // reset low
  oled_resn = 0;  
  // wait some
  () <- wait <- (1000);
  // reset high
  oled_resn = 1;
  
  // 300 msec @100Mhz  
  () <- wait <- (7500000);

  // send screen-on command
  () <- sendCommand <- (8haf);
  // 300 msec @100Mhz
  () <- wait <- (7500000);

  // select auto horiz. increment, 666 RGB 
  () <- sendCommand <- (8ha0);
  () <- sendData    <- (8b10100000);
  
  // unlock
  () <- sendCommand <- (8hfd);
  () <- sendData    <- (8hb1);
  
  // set vertical scroll to 0
  () <- sendCommand <- (8ha2);
  () <- sendData    <- (8h00);
  
  //---------------
  // Init done!
  //--------------  

  // ready to accept commands
  io.ready = 1;

  while (1) {

    if (io.start_rect) {
      io.ready = 0;
      // set col addr
      () <- sendCommand <- (8h15);
      () <- sendData    <- (io.x_start);
      () <- sendData    <- (io.x_end);
      // set row addr
      () <- sendCommand <- (8h75);
      () <- sendData    <- (io.y_start);
      () <- sendData    <- (io.y_end);
      // initiate write
      () <- sendCommand <- (8h5c);
      io.ready = 1;
    } else { // this else is important to ensure the loop remain a one-cycle loop when not entering the if-s
      if (io.next_pixel) {
        io.ready = 0;
        // send pixel
        () <- sendData <- (io.color[12,6]);
        () <- sendData <- (io.color[ 6,6]);
        () <- sendData <- (io.color[ 0,6]);
        io.ready = 1;
      }
    }
  }

}

// ------------------------- 
