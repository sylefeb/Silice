// SL 2020-07
// Debug placeholder

// -------------------------
// Main drawing algorithm

algorithm doomchip(
  column_io colio {
    input   draw_col,
    output  y,
    output  palidx,
    output  write,
    output  done,
  },
  input uint1   vsync,
$$if DE10NANO then  
  output uint4  kpadC,
  input  uint4  kpadR,
  output uint8  led,
  output uint1  lcd_rs,
  output uint1  lcd_rw,
  output uint1  lcd_e,
  output uint8  lcd_d,
  output uint1  oled_din,
  output uint1  oled_clk,
  output uint1  oled_cs,
  output uint1  oled_dc,
  output uint1  oled_rst,
$$end
$$if ULX3S then
  output uint8 led,
  input  uint7 btn,
$$end  
) 
<autorun> 
{

  uint10 c = 0;
  uint16 offset = 0;

$$if ULX3S then  
  led         := 0;
$$end
  colio.write := 0;
  colio.done  := 0;
  
  while (1) {
    
    // ----------------------------------------------
    // rendering
    // ----------------------------------------------
    c = 0;    
    while (c < $doomchip_width$) { 

      uint10 y = 0;

      __display("c = %d",c);
      while (c != colio.draw_col) { /*wait*/ }
      __display("c passed = %d",c);

      while (y < $doomchip_height$) {
$$if doomchip_vflip then
        colio.y      = $doomchip_height-1$ - y;
$$else
        colio.y      = y;
$$end
        colio.palidx = y + offset + c;  
        colio.write  = 1;
        y = y + 1;
      }
      colio.done = 1;
      c = c + 1;
    }
    
    // ----------------------------------------------
    // end of frame
    // ----------------------------------------------

    offset = offset + 1;
    
    // wait for vsync to end
    while (vsync == 0) {  }
    
  }
}
