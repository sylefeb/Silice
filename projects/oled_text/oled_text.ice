// SL 2020-08

// Select screen driver below
$$ -- SSD1351=1
$$ ST7789=1
$include('../common/oled.ice')

$$if not ULX3S and not DE10NANO then
$$error('only tested on ULX3S and DE10NANO, small changes likely required to main input/outputs for other boards')
$$end

// ------------------------- 

algorithm text_display(
  input   uint10 pix_x,
  input   uint10 pix_y,
  output  uint1  white,
  output! uint12 letter_addr,
  input   uint6  letter,
) <autorun> {

  // ---------- font  
$include('../common/font.ice')
$$if letter_w ~= 8 or letter_h ~= 8 then
  error('expects a 8x8 font')
$$end
  
  // ---------- text display

  uint6  text_i   = 0;
  uint6  text_j   = 0;
  uint4  letter_i = 0;
  uint5  letter_j = 0;
  uint12 addr     = 0;

  // ---------- show time!

  while (1) {

    // text
    letter_i = pix_x & 7;
    text_i   = pix_x >> 3;
    letter_j = pix_y & 7;
    text_j   = pix_y >> 3;
    
    if (text_i < 32 && text_j < 32) {
      letter_addr = text_i + (text_j*$oled_width>>3$);
++:      
      addr        = letter_i + ( letter_j << 3) 
                             + (letter << 6);
      white       = letters[ addr ];
    } else {
      white    = 0;
    }

  }
  
}

// ------------------------- 

algorithm main(
$$if ULX3S then
  output! uint8 leds,
  input   uint7 btn,
  output! uint1 oled_clk,
  output! uint1 oled_mosi,
  output! uint1 oled_dc,
  output! uint1 oled_resn,
  output! uint1 oled_csn,
$$end
$$if DE10NANO then
  output! uint8 leds,
  output! uint4 kpadC,
  input   uint4 kpadR,
  output! uint1 lcd_rs,
  output! uint1 lcd_rw,
  output! uint1 lcd_e,
  output! uint8 lcd_d,
  output! uint1 oled_din,
  output! uint1 oled_clk,
  output! uint1 oled_cs,
  output! uint1 oled_dc,
  output! uint1 oled_rst,  
  output! uint1  sdram_cle,
  output! uint1  sdram_dqm,
  output! uint1  sdram_cs,
  output! uint1  sdram_we,
  output! uint1  sdram_cas,
  output! uint1  sdram_ras,
  output! uint2  sdram_ba,
  output! uint13 sdram_a,
  output! uint1  sdram_clk,
  inout   uint8  sdram_dq,
  output! uint$color_depth$ video_r,
  output! uint$color_depth$ video_g,
  output! uint$color_depth$ video_b,
  output! uint1 video_hs,
  output! uint1 video_vs
$$end
) {

  oledio io;
  oled   display(
$$if ULX3S then
    oled_clk  :> oled_clk,
    oled_mosi :> oled_mosi,
    oled_dc   :> oled_dc,
    oled_resn :> oled_resn,
    oled_csn  :> oled_csn,
$$end
$$if DE10NANO then
    oled_clk  :> oled_clk,
    oled_mosi :> oled_din,
    oled_dc   :> oled_dc,
    oled_resn :> oled_rst,
    oled_csn  :> oled_cs,
$$end
    io       <:> io
  );

  // Text buffer
  dualport_bram uint6 txt[$(oled_width*oled_height)>>6$] = uninitialized;

  uint11 str_x    = 0;
  uint10 str_y    = 0;
  
  // ---------- string
  uint8  str[] = "   HELLO WORLD FROM FPGA #    THIS IS WRITTEN IN SILICE# A LANGUAGE FOR FPGA DEVEL #FUN AND SIMPLE YET POWERFUL #";

  // --------- print string
  subroutine print_string(
	  reads      str,
	  reads      str_x,
	  readwrites str_y,
    writes     txt,
	  ) {
    uint10 col  = 0;
    uint8  lttr = 0;
    uint6  offs = 0;
    // print line
    while (str[col] != 0) {
      if (str[col] == 35) {
        str_y = str_y + 1;
        offs  = 0;
      } else {
        switch (str[col]) {
          case 32: {lttr = 36;}
          case 45: {lttr = 37;}
          default: {lttr = str[col] - 55;}
        }
        txt.addr1   = offs + str_x + (str_y*$oled_width>>3$);
        txt.wdata1  = lttr[0,6];
        offs        = offs + 1;
      }
      col       = col + 1;
    }
    return;
  }

  // --------- display
  uint10 u     = 0;
  uint10 v     = 0;
  uint1  white = 0;
  text_display text(
    pix_x  <: u,
    pix_y  <: v,
    white :> white,
    letter_addr :> txt.addr0,
    letter      <: txt.rdata0
  );

  uint16 frame = 0;

  leds := frame[0,8];

  // maintain low (pulses high when sending)
  io.start_rect := 0;
  io.next_pixel := 0;

  txt.wenable0  := 0;
  txt.wenable1  := 1;
    
  // fill buffer with spaces
  {
    uint11 next = 0;
    txt.wdata1   = 36; // data to write
    next         = 0;
    while (next < 1024) {
      txt.addr1 = next;     // address to write
      next      = next + 1; // next
    }
  }
  
	// write text in buffer    
  str_y = 0;
  () <- print_string <- ();

  // wait for controller to be ready  
  while (io.ready == 0) { }

  // setup draw window
  io.x_start = 0;
  io.x_end   = $oled_width-1$;
  io.y_start = 0;
  io.y_end   = $oled_height-1$;
  io.start_rect = 1;
  while (io.ready == 0) { }

  while (1) {

    // refresh (framebuffer style, even though the OLED
    // screen could support random access ...
    v = 0;
    while (v < $oled_height$) {
      u = 0;
      while (u < $oled_width$) {
        // wait for text module to refresh given new u,video_b
        // (NOTE: a cycle could be saved by working one delayed)
++:
        io.color      = white ? 18h3ffff : 0;
        io.next_pixel = 1;
        while (io.ready == 0) { }
        
        u = u + 1;
      }
      v = v + 1;
    }
    
    frame = frame + 1;
   
  }

}

// ------------------------- 
