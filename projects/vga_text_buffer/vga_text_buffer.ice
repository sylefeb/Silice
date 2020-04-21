// -------------------------

// VGA driver
$include('../common/vga.ice')

$$if MOJO then
// Clock
import('../common/mojo_clk_100_25.v')
$$end
$$if ICESTICK then
// Clock
import('../common/icestick_clk_vga.v')
$$end

$$if HARDWARE then
// Reset
import('../common/reset_conditioner.v')
$$end

$$if MOJO then
$$max_color = 1
$$else
$$max_color = 15
$$end

// -------------------------

algorithm text_display(
  input   uint10 pix_x,
  input   uint10 pix_y,
  input   uint1  pix_active,
  input   uint1  pix_vblank,
  output! uint4  pix_red,
  output! uint4  pix_green,
  output! uint4  pix_blue
) <autorun> {

  // Text buffer
  bram uint6 txt[1024];

  // ---------- font
  // assumes letter_w_sp (defined in font) is an integer divider of 640
  
  $include('../common/font.ice')
  // include('../common/font_small.ice')

  // ---------- text display

  uint5  text_i   = 0;
  uint5  text_j   = 0;
  uint4  letter_i = 0;
  uint5  letter_j = 0;
  uint1  pixel    = 0;
  uint12 addr     = 0;

  uint10 shf_x    = 0;

  uint11 next     = 0;

  uint11 str_x    = 0;
  uint10 str_y    = 0;

  int10  frame    = 0;
  uint4  line     = 0;
  
  uint4  stride   = 0;

  // ---------- table for text swim
  uint4 wave[64] = {
$$for i=0,63 do
    $math.floor(15.0 * (0.5+0.5*math.sin(2*math.pi*i/63)))$,
$$end
  };
  
  // ---------- snow
  int10 dotpos = 0;
  int2  speed  = 0;
  int2  inv_speed = 0;
  int12 rand_x = 0;

  // ---------- string
  uint8  str[] = "   HELLO WORLD FROM FPGA #    THIS IS WRITTEN IN # MY LANGUAGE FOR FPGA DEVEL #FUN AND SIMPLE YET POWERFUL#   --- COMING SOON --- ##THIS WAS TESTED ON#-VERILATOR#-ICARUS VERILOG#-MOJO BOARD#-ICESTICK##HERE ON ICESTICK#WITH OPEN-SOURCE TOOLS";

  // --------- print string
  subroutine print_string( 
	  reads      str,
	  reads      str_x,
	  readwrites str_y,
    writes     txt_addr,
	  writes     txt_wdata,
	  writes     txt_wenable
	  ) {
    uint10 col  = 0;
    uint8  lttr = 0;
    uint5  offs = 0;
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
        txt_addr    = offs + str_x + (str_y << 5);
        txt_wdata   = lttr[0,6];
        txt_wenable = 1;
        offs        = offs + 1;
      }
      col       = col + 1;
    }
    txt_wenable = 0;
    return;
  }

  // by default r,g,b are set to zero
  pix_red   := 0;
  pix_green := 0;
  pix_blue  := 0;

  // fill buffer with spaces
  txt_wenable  = 1;
  txt_wdata    = 36; // data to write
  next         = 0;
  while (next < 1024) {
    txt_addr  = next;     // address to write
    next      = next + 1; // next
  }
  txt_wenable = 0;

  // ---------- show time!
  
  while (1) {

	  // write lines in buffer
    
    str_y = 0;
    () <- print_string <- ();
    
    // wait until vblank is over
    
	  while (pix_vblank == 1) { }
    frame = frame + 1;

	  // display frame
    
    text_i   = 0;  
    text_j   = 0;
    letter_i = 0;
    letter_j = 0;
    
	  while (pix_vblank == 0) {

      if (pix_active) {

        // background snow effect        
        if (pix_x == 0) {
          rand_x = 1;
        } else {
          rand_x = rand_x * 31421 + 6927;
        }
        speed  = rand_x[10,2];
        dotpos = (frame >> speed) + rand_x;
        if (pix_y == dotpos) {
          pix_red   = ($max_color$);
          pix_green = ($max_color$);
          pix_blue  = ($max_color$);
        }        
        
        // text
        stride = wave[pix_y[2,6] + frame[0,6]];
        if (pix_x >= 192 + stride && pix_y > 64) {        
        
          if (letter_j < $letter_h$ && letter_i < $letter_w$) {
            addr     = letter_i + (letter_j << $letter_w_pow2$) 
                      + (txt_rdata * $letter_w*letter_h$);
            pixel    = letters[ addr ];
            if (pixel == 1) {
              switch (text_j)
              {
              case 0: {
                pix_red   = 0;
                pix_green = $max_color$;
                pix_blue  = 0;
              }
              case 4: {
                pix_red   = 0;
                pix_green = 0;
                pix_blue  = $max_color$;
              }
              case 6: {
                pix_red   = $max_color$;
                pix_green = 0;
                pix_blue  = 0;
              }
              default: {
                pix_red   = $max_color$;
                pix_green = $max_color$;
                pix_blue  = $max_color$;
              }
              }
            }
          }
          
          letter_i = letter_i + 1;
          if (letter_i == $letter_w_sp$) { // end of letter
            letter_i = 0;
            if (text_i < 31) {
              text_i = text_i + 1;
            }
          }
          
          if (pix_x == 639) {  // end of line
            // back to first column
            text_i   = 0;
            letter_i = 0;
            // next letter line
            if (letter_j < $2*letter_h$) {
              letter_j = letter_j + 1;
            } else {
              // next text row
              text_j   = text_j + 1;
              letter_j = 0; // back to first letter line
            }
          }

          txt_addr = text_i + (text_j << 5);

        }      


      }		
	  }

  }
}

// -------------------------

algorithm main(
$$if MOJO then
  output! uint8 led,
  output! uint1 spi_miso,
  input   uint1 spi_ss,
  input   uint1 spi_mosi,
  input   uint1 spi_sck,
  output! uint4 spi_channel,
  input   uint1 avr_tx,
  output! uint1 avr_rx,
  input   uint1 avr_rx_busy,
$$end
$$if MOJO or VERILATOR then
  // SDRAM
  output! uint1  sdram_cle,
  output! uint1  sdram_dqm,
  output! uint1  sdram_cs,
  output! uint1  sdram_we,
  output! uint1  sdram_cas,
  output! uint1  sdram_ras,
  output! uint2  sdram_ba,
  output! uint13 sdram_a,
$$if VERILATOR then
  output! uint1  sdram_clock,
  input   uint8  sdram_dq_i,
  output! uint8  sdram_dq_o,
  output! uint1  sdram_dq_en,
$$else
  output! uint1  sdram_clk,
  inout   uint8  sdram_dq,
$$end
$$end
$$if ICESTICK then
  output! uint1 led0,
  output! uint1 led1,
  output! uint1 led2,
  output! uint1 led3,
  output! uint1 led4,
$$end
$$if SIMULATION then
  output! uint1 video_clock,
$$end
  output! uint4 video_r,
  output! uint4 video_g,
  output! uint4 video_b,
  output! uint1 video_hs,
  output! uint1 video_vs
) 
$$if HARDWARE then
// on an actual board, the video signal is produced by a PLL
<@video_clock,!video_reset> 
$$end
{

$$if HARDWARE then
  uint1 video_reset = 0;
  uint1 video_clock = 0;
$$if MOJO then
  uint1 sdram_clock = 0;
  // --- clock
  clk_100_25 clk_gen (
    CLK_IN1  <: clock,
    CLK_OUT1 :> sdram_clock,
    CLK_OUT2 :> video_clock
  );
  // --- sdram reset
  uint1 sdram_reset = 0;
  reset_conditioner sdram_rstcond (
    rcclk <: sdram_clock,
    in  <: reset,
    out :> sdram_reset
  );
$$elseif ICESTICK then
  // --- clock
  icestick_clk_vga clk_gen (
    clock_in  <: clock,
    clock_out :> video_clock,
    lock      :> led4
  );
$$end
  // --- video reset
  reset_conditioner vga_rstcond (
    rcclk <: video_clock,
    in  <: reset,
    out :> video_reset
  );
$$end

  uint1  active = 0;
  uint1  vblank = 0;
  uint10 pix_x  = 0;
  uint10 pix_y  = 0;

  vga vga_driver 
$$if HARDWARE then
  <@video_clock,!video_reset>
$$end
  (
    vga_hs :> video_hs,
	  vga_vs :> video_vs,
	  active :> active,
	  vblank :> vblank,
	  vga_x  :> pix_x,
	  vga_y  :> pix_y
  );

  text_display display
$$if HARDWARE then
  <@video_clock,!video_reset>
$$end  
  (
	  pix_x      <: pix_x,
	  pix_y      <: pix_y,
	  pix_active <: active,
	  pix_vblank <: vblank,
	  pix_red    :> video_r,
	  pix_green  :> video_g,
	  pix_blue   :> video_b
  );

  uint8 frame  = 0;

$$if MOJO then
  // unused pins
  spi_miso := 1bz;
  avr_rx := 1bz;
  spi_channel := 4bzzzz;
$$end

$$if SIMULATION then
  video_clock := clock;
$$end

$$if SIMULATION then
  // we count a number of frames and stop
  while (frame < 40) {
    while (vblank == 1) { }
	  $display("vblank off");
    while (vblank == 0) { }
    $display("vblank on");
    frame = frame + 1;
  }
$$else
  // forever
  while (1) { }
$$end
  
}

