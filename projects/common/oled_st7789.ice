// SL 2020-07
// ------------------------- 
// OLED RGB screen driver (ST7789)
// ------------------------- 

group oledio {
  uint9  x_start     = 0,
  uint9  x_end       = 0,
  uint9  y_start     = 0,
  uint9  y_end       = 0,
  uint18 color       = 0,
  uint1  start_rect  = 0,
  uint1  next_pixel  = 0,
  uint1  ready       = 0 
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
  uint10 sending    = 0;
  
  always {
    oled_dc  =  dc;
    osc      =  (sending>1) ? {osc[0,1],osc[1,1]} : 1;
    oled_clk =  (!(sending>1)) || (osc[1,1]); // SPI Mode 3
    if (enable) {
      dc         = data_or_command;
      oled_dc    =  dc;
      sending    = {1b1,
        byte[0,1],byte[1,1],byte[2,1],byte[3,1],
        byte[4,1],byte[5,1],byte[6,1],byte[7,1],1b0};
    } else {
      oled_mosi = sending[0,1];
      if (osc[1,1]) {
        sending   = {1b0,sending[1,9]};
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

  subroutine wait(input uint24 delay)
  {
    uint24 count = 0;
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
    oled_dc   :> oled_dc
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
$$if st7789_no_cs then
  oled_csn := 1; // backlight 
$$else
  oled_csn := 0; // enable chip
$$end
  enable   := 0; // maintained low, pulses high

  //---------------
  // Initializing
  //---------------
  io.ready = 0;

  // reset high
  oled_resn = 1;
  // wait
  () <- wait        <- (2000000); // 80 msec @25Mhz
  // reset low
  oled_resn = 0;
  // wait
  () <- wait        <- (2000000); // 80 msec @25Mhz
  // reset high
  oled_resn = 1;
  // wait
  () <- wait        <- (2000000); // 80 msec @25Mhz
  
  // software reset
  () <- sendCommand <- (8h01);
  // wait
  () <- wait        <- (4500000); // 180 msec @25Mhz

  // sleep out
  () <- sendCommand <- (8h11);
  // wait
  () <- wait        <- (3000000); // 120 msec @25Mhz
  
  // colmod
  () <- sendCommand <- (8h3A);
  () <- sendData    <- (8b01100110);
  () <- wait        <- (300000); // 12 msec @25Mhz

  // madctl
  () <- sendCommand <- (8h36);
  //                      MY MX MV ML RGB MH - -
$$if st7789_transpose then  
  () <- sendData    <- (8b00100000);
$$else
  () <- sendData    <- (8b00000000);
$$end
  () <- wait        <- (300000); // 12 msec @25Mhz

  // invon
  () <- sendCommand <- (8h21);
  () <- wait        <- (300000); // 12 msec @25Mhz

  // noron
  () <- sendCommand <- (8h13);
  () <- wait        <- (300000); // 12 msec @25Mhz

  // brightness  
  () <- sendCommand <- (8h51);
  () <- sendData    <- (8d255);
  
  // display on
  () <- sendCommand <- (8h29);
  () <- wait        <- (4500000); // 180 msec @25Mhz
  
  //---------------
  // Init done!
  //--------------  

  // ready to accept commands
  io.ready = 1;

  while (1) {

    if (io.start_rect) {
      io.ready = 0;
      // set bounds
      // columns
      () <- sendCommand <- (8h2A);
      () <- sendData    <- ({7b0,io.x_start[8,1]});
      () <- sendData    <- (io.x_start[0,8]);
      () <- sendData    <- ({7b0,io.x_end[8,1]});
      () <- sendData    <- (io.x_end[0,8]);
      () <- sendCommand <- (8h2B);
      () <- sendData    <- ({7b0,io.y_start[8,1]});
      () <- sendData    <- (io.y_start[0,8]);
      () <- sendData    <- ({7b0,io.y_end[8,1]});
      () <- sendData    <- (io.y_end[0,8]);
      // start writing to ram
      () <- sendCommand <- (8h2C);
      // ready!
      io.ready = 1;
    } else { // this else is important to ensure the loop remain a one-cycle loop when not entering the if-s
      if (io.next_pixel) {
        io.ready = 0;
        // send pixel
        () <- sendData    <- (io.color[ 0,6]);
        () <- sendData    <- (io.color[ 6,6]);
        () <- sendData    <- (io.color[12,6]);
        io.ready = 1;
      }
    }
  }

}

// ------------------------- 
