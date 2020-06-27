// SL 2020-05
// ------------------------- 
// LCD1602 driver
// ------------------------- 

group lcdio {
  uint8 data    = 0,
  uint1 print   = 0,
  uint1 clear   = 0,
  uint1 setrow  = 0,
  uint1 ready   = 0  
}

algorithm lcd(
  output uint1 lcd_rs,
  output uint1 lcd_rw,
  output uint1 lcd_e,
  output uint8 lcd_d,
  lcdio io {
    input  data,
    input  print,
    input  clear,
    input  setrow,
    output ready
  }
) <autorun> {

  subroutine send(writes lcd_e)
  {
    uint8 count = 0; 
    lcd_e  = 1;
    // 250 ns @100Mhz
    while (count < 250) {
      count = count + 1;
    }
    lcd_e  = 0;
  }
  
  subroutine wait(input uint24 delay)
  {
    uint24 count = 0;
    while (count < delay) {
      count = count + 1;
    }   
  }
  
  subroutine printLetter(
    calls  send,
    calls  wait,
    writes lcd_rs,
    writes lcd_d,
    input  uint8 lttr
  ) {
    lcd_rs = 1;
    lcd_d  = lttr;
    () <- send <- ();    
    () <- wait <- (5300); // 53 usec @100Mhz
  }

  subroutine clear(
    calls  send,
    calls  wait,
    writes lcd_rs,
    writes lcd_d,
  ) {
    lcd_rs = 0;
    lcd_d  = 8b00000001;
    () <- send <- ();    
    () <- wait <- (300000); // 3 msec @100Mhz
  }
  
  subroutine setAddress(
    calls  send,
    calls  wait,
    writes lcd_rs,
    writes lcd_d,
    input  uint8 addr
  ) {
    lcd_rs = 0;
    lcd_d  = {1b1,addr[0,7]};
    () <- send <- ();    
    () <- wait <- (5300);  // 53 usec @100Mhz
  }

  uint4 n = 0;
  
  //---------------
  // Intializing
  //---------------

  io.ready = 0;
  
  lcd_rs = 0;
  lcd_rw = 0;
  lcd_d  = 0;

  // assuming cold start
  // 100 msec @100Mhz
  n = 0;
  while (n < 10) {
    () <- wait <- (1000000);
    n = n + 1;
  }
  
  lcd_d  = 8b00110000;
  () <- send <- ();
  // 4.1 msec @100Mhz
  () <- wait <- (410000);

  lcd_d  = 8b00110000;
  () <- send <- ();
  // 100 usec @100Mhz
  () <- wait <- (10000);
  
  lcd_d  = 8b00110000;
  () <- send <- ();
  // 100 usec @100Mhz
  () <- wait <- (10000);

  lcd_d  = 8b00111000;
  () <- send <- ();
  // 53 usec @100Mhz
  () <- wait <- (5300);

  lcd_d  = 8b00001000;
  () <- send <- ();
  // 53 usec @100Mhz
  () <- wait <- (5300);
  
  lcd_d  = 8b00000001;
  () <- send <- ();
  // 3 msec @100Mhz
  () <- wait <- (300000);
    
  lcd_d  = 8b00000110;
  () <- send <- ();
  // 53 usec @100Mhz
  () <- wait <- (5300);

  lcd_d  = 8b00001100; // last two bits are cursor and blink
  () <- send <- ();
  // 53 usec @100Mhz
  () <- wait <- (5300);

  //---------------
  // Init done!
  //--------------  

  io.ready = 1;
  
  while (1) {
    if (io.print) {
      io.ready = 0;
      () <- printLetter <- (io.data);
      io.ready = 1;
    } else {
      if (io.clear) {
        io.ready = 0;
        () <- clear <- ();
        io.ready = 1;      
      } else {
        if (io.setrow) {
          io.ready = 0;
          switch (io.data) {
            case 0:  { () <- setAddress <- (0);  }
            case 1:  { () <- setAddress <- (40); }
            default: { () <- setAddress <- (0);  }
          }
          io.ready = 1;      
        }      
      }
    }
  }
  
}

// ------------------------- 
