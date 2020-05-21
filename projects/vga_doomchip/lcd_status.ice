// SL 2020-05
$include('lcd.ice')

// ------------------------- 

algorithm lcd_status(
  output uint1  lcd_rs,
  output uint1  lcd_rw,
  output uint1  lcd_e,
  output uint8  lcd_d,
  input  uint16 posx,
  input  uint16 posy
) <autorun> {

  lcdio io;
  lcd   display(
    lcd_rs :> lcd_rs,
    lcd_rw :> lcd_rw,
    lcd_e  :> lcd_e,
    lcd_d  :> lcd_d,
    io    <:> io
  );

  uint8  msg1 [17] = "DooM-chip   v0.1";
  uint8  chars[]   = "E1M1 XY";
  uint26 counter   = 1;
  
  subroutine printMessage(
    readwrites  io,
    input uint8 msg[17]
  ) {
    uint8 i = 0;  
    while (msg[i] != 0) {
      while (io.ready == 0) { }
      io.data   = msg[i];
      io.print  = 1;
      i         = i + 1;
    }
  }
  
  subroutine printNumber(
    readwrites   io,
    input uint16 v
  ) {
    uint5 n = 0;
    uint4 h = 0;
    while (n < 16) {
      while (io.ready == 0) { }
      h        = (v >> n);
      if (h < 10) {
        io.data  = 48 + h;
      } else {
        io.data  = 97 + (h-10);
      }
      io.print = 1;   
      n = n + 4;
    }
  }
  
  uint8  i   = 0;
  uint24 cnt = 0;
  
  io.print  := 0;
  io.setrow := 0;

  // row 0
  while (io.ready == 0) { }
  io.data   = 1;
  io.setrow = 0;

  () <- printMessage <- (msg1);

  while (1) {
    
    // row 1
    while (io.ready == 0) { }
    io.data   = 1;
    io.setrow = 1;
    
    i = 0;
    while (i<4) {
      while (io.ready == 0) { }
      io.data  = chars[i];
      io.print = 1;   
      i = i + 1;
    }
    
    // space
    while (io.ready == 0) { }
    io.data  = chars[4];
    io.print = 1;   
    
    // X
    while (io.ready == 0) { }
    io.data  = chars[5];
    io.print = 1;   
    
    () <- printNumber <- (posx);
    
    // Y
    while (io.ready == 0) { }
    io.data  = chars[6];
    io.print = 1;   

    () <- printNumber <- (posy);
    
    // wait some
    cnt = 1;
    while (cnt != 0) {
      cnt = cnt + 1;
    }
    
  }
}

// ------------------------- 
