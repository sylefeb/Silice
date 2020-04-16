// -------------------------

// Text buffer (small 32x32)
import('../common/text_buffer_small.v')

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

uint14 txtaddr   = 0;
uint6  txtdata_r = 0;
uint6  txtdata_w = 0;
uint1  txtwrite  = 0;

text_buffer txtbuf (
  clk     <: clock,
  addr    <: txtaddr,
  wdata   <: txtdata_w,
  rdata   :> txtdata_r,
  wenable <: txtwrite
);

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
//if SIMULATION then
  uint1  delay    = 0;
//else
//  uint23 delay    = 0;
//end

  // snow
  int10 dotpos = 0;
  int2  speed  = 0;
  int2  inv_speed = 0;
  int12 rand_x = 0;

  // ---------- string
  uint8  str[] = "   HELLO WORLD FROM FPGA #   THIS IS WRITTEN IN #       -- SILICE -- # A LANGUAGE FOR FPGA DEVEL #FUN AND SIMPLE YET POWERFUL###THIS WAS TESTED ON#-VERILATOR#-ICARUS VERILOG#-MOJO BOARD#-ICESTICK##FULLY IMPLEMENTED IN SILICE#VGA TEXT AND EFFECTS";

  // --------- print string
  subroutine print_string( 
	  reads      str,
	  reads      str_x,
	  reads      str_y,
    reads      line,
	  writes     txtaddr,
	  writes     txtdata_w,
	  writes     txtwrite
	  ) {
    uint12 col  = 0;
    uint8  lttr = 0;
    uint8  numl = 0;
    uint12 offs = 0;
	  // count lines
    while (str[col] != 0 && numl != line) {
      if (str[col] == 35) {
        numl    = numl + 1;
      }
      col       = col + 1;
    }
    // print line
    while (str[col] != 0 && str[col] != 35) {
      switch (str[col]) {
        case 32: {lttr = 36;}
        case 45: {lttr = 37;}
        default: {lttr = str[col] - 55;}
      }
      txtaddr   = offs + str_x + (str_y << 5);
      txtdata_w = lttr[0,6];
      txtwrite  = 1;
      col       = col + 1;
      offs      = offs + 1;
    }
    txtwrite = 0;
    return;
  }

  // by default r,g,b are set to zero
  pix_red   := 0;
  pix_green := 0;
  pix_blue  := 0;

  // fill buffer with spaces
  txtwrite  = 1;
  txtdata_w = 36; // data to write
  next      = 0;
  while (next < 1024) {
    txtaddr = next;     // address to write
    next    = next + 1; // next
  }
  txtwrite = 0;

  // ---------- show time!
  
  letter_i = 0;
  
  while (1) {

	  // write next line in buffer
    if (delay == 0) {
      if (line < 15) {
        () <- print_string <- ();
        line  = line  + 1;
        str_y = str_y + 1;
      } else {
        str_y = 0;
      }
    }
    delay = delay + 1;
    
    // wait until vblank is over
	  while (pix_vblank == 1) { }
    frame = frame + 1;

	  // display frame
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
        
        if (letter_j < $letter_h$ && letter_i < $letter_w$) {
          addr     = letter_i + (letter_j << $letter_w_pow2$) 
                    + (txtdata_r * $letter_w*letter_h$);
          pixel    = letters[ addr ];
          if (pixel == 1) {
            switch (text_j)
            {
            case 0: {
              pix_red   = 0;
              pix_green = $max_color$;
              pix_blue  = 0;
            }
            case 1: {
              pix_red   = 0;
              pix_green = 0;
              pix_blue  = $max_color$;
            }
            case 3: {
              pix_red   = 0;
              pix_green = 0;
              pix_blue  = $max_color$;
            }
            case 4: {
              pix_red   = 0;
              pix_green = 0;
              pix_blue  = $max_color$;
            }
            case 7: {
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
          if (pix_x == 639) {  // end of line
            // back to first column
            text_i   = 0;
            // end of frame ?
            if (pix_y == 479) {
              // yes
              text_j   = 0;
              letter_j = 0;
            } else {
                // next letter line
              if (letter_j < $2*letter_h$) {
                letter_j = letter_j + 1;
              } else {
                // next text row
                text_j   = text_j + 1;
                letter_j = 0; // back to first letter line
              }
            }
          } else {
            if (text_i < 31) {
              text_i = text_i + 1;
            }
          }
        }
      }      

      txtaddr  = text_i + (text_j << 5);
		
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

$$if MOJO then
  // unused pins
  spi_miso := 1bz;
  avr_rx := 1bz;
  spi_channel := 4bzzzz;
$$end

  uint8 frame  = 0;

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

