// ---------------------------------------------------

algorithm keypad(
  output uint4  kpadC,
  input  uint4  kpadR,
  output uint16 pressed
) <autorun> {
  uint2 col = 0;
  kpadC     = 4b1111;
  while (1) {    
    pressed[{col,2b00},4] = ~kpadR;    
    // next
    col   = (col + 1);
    kpadC = ~(1 << col);
  }
}

// ---------------------------------------------------
