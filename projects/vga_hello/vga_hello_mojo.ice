// SL 2019-10

// Text buffer
import('../common/text_buffer.v')

// VGA driver
$include('../common/vga.ice')

// Clock
import('../common/mojo_clk_100_25.v')

// Reset
import('../common/reset_conditioner.v')

// -------------------------

algorithm text_display(
  input   uint10 pix_x,
  input   uint10 pix_y,
  input   uint1  pix_active,
  input   uint1  pix_vblank,
  output! uint1  pix_red,
  output! uint1  pix_green,
  output! uint1  pix_blue
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
  
  $include('../common/font.ice')
   
  // ---------- text display

  uint8  text_i   = 0;
  uint7  text_j   = 0;
  uint3  letter_i = 0;
  uint4  letter_j = 0;
  uint1  pixel    = 0;
  uint12 addr     = 0;

  uint16 next     = 0;

  uint11 str_x    = 30;
  uint10 str_y    = 0;

  int32   numb     = -32h1234;
  uint32  numb_tmp = 0;
  uint8   numb_cnt = 0;

  // ---------- string

  uint8  str[] = "HELLO WORLD FROM FPGA";
  uint8  tmp   = 0;
  uint8  step  = 0;

  // --------- print string
  subroutine print_string( 
	  reads      str,
	  reads      str_x,
	  reads      str_y,
	  writes     txtaddr,
	  writes     txtdata_w,
	  writes     txtwrite
	  )
    uint11 col  = 0;
    uint8  lttr = 0;
	
    while (str[col] != 0) {
      if (str[col] == 32) {
        lttr = 36;
      } else {
        lttr = str[col] - 55;
      }
      txtaddr   = col + str_x + str_y * 80;
      txtdata_w = lttr[0,6];
      txtwrite  = 1;
      col       = col + 1;
    }
	txtwrite = 0;
  return;

  // by default r,g,b are set to zero
  pix_red   := 0;
  pix_green := 0;
  pix_blue  := 0;

  // fill buffer with spaces
  txtwrite  = 1;
  next      = 0;
  txtdata_w = 36; // data to write
  while (next < 4800) {
    txtaddr = next;     // address to write
    next    = next + 1; // next
  }
  txtwrite = 0;

  // ---------- show time!

  while (1) {

	  // prepare next frame
	  () <- print_string <- ();
    if (str_y < 52) {   
	    str_y = str_y + 1;
    } else {
      str_y = 0;
    }
    
      // wait until vblank is over
	  while (pix_vblank == 1) { }

	  // display frame
	  while (pix_vblank == 0) {

    if (pix_active) { // when not active pixels *have* to be blank, otherwise the monitor gets confused
      pix_blue  = pix_x[4,1];
      pix_green = pix_y[4,1];
      pix_red   = 0;
    }
    
		if (letter_j < 8) {
		  letter_i = pix_x & 7;
		  addr     = letter_i + (letter_j << 3) + (txtdata_r << 6);
		  pixel    = letters[ addr ];
		  if (pixel == 1) {
			  pix_red   = 1;
			  pix_green = 1;
			  pix_blue  = 1;
		  }
		}

		if (pix_active && (pix_x & 7) == 7) {   // end of letter
		  if (pix_x == 639) {  // end of line
	        // back to first column
        	text_i   = 0;
			// end of frame ?
			if (pix_y == 479) {
			  // yes
			  text_j   = 0;
			  letter_j = 0;
			} else {
  			  // no: next letter line
			  if (letter_j < 8) {
			    letter_j = letter_j + 1;
			  } else {
			    // next row
			    letter_j = 0;
			    text_j   = text_j + 1;
			  }
			}
		  } else {
		    text_i = text_i + 1;		  
		  }
		}

		txtaddr  = text_i + text_j * 80;
		
	  }

  }
}

// -------------------------

algorithm main(
  output uint8 led,
  output uint1 spi_miso,
  input  uint1 spi_ss,
  input  uint1 spi_mosi,
  input  uint1 spi_sck,
  output uint4 spi_channel,
  input  uint1 avr_tx,
  output uint1 avr_rx,
  input  uint1 avr_rx_busy,
  // SDRAM
  output uint1 sdram_clk,
  output uint1 sdram_cle,
  output uint1 sdram_dqm,
  output uint1 sdram_cs,
  output uint1 sdram_we,
  output uint1 sdram_cas,
  output uint1 sdram_ras,
  output uint2 sdram_ba,
  output uint13 sdram_a,
  inout  uint8 sdram_dq,
  // VGA
  output uint1 vga_r,
  output uint1 vga_g,
  output uint1 vga_b,
  output uint1 vga_hs,
  output uint1 vga_vs
) <@vga_clock,!vga_reset> {

  uint1 vga_clock   = 0;
  uint1 vga_reset   = 0;
  uint1 sdram_reset = 0;
  uint1 sdram_clock = 0;

  // --- clock

  clk_100_25 clk_gen (
    CLK_IN1  <: clock,
    CLK_OUT1 :> sdram_clock,
    CLK_OUT2 :> vga_clock
  );

  // --- clean reset

  reset_conditioner vga_rstcond (
    rcclk <: vga_clock,
    in  <: reset,
    out :> vga_reset
  );

  reset_conditioner sdram_rstcond (
    rcclk <: sdram_clock,
    in  <: reset,
    out :> sdram_reset
  );

  uint1  active = 0;
  uint1  vblank = 0;
  uint10 pix_x  = 0;
  uint10 pix_y  = 0;

  vga vga_driver<@vga_clock,!vga_reset>(
    vga_hs :> vga_hs,
	  vga_vs :> vga_vs,
	  active :> active,
	  vblank :> vblank,
	  vga_x  :> pix_x,
	  vga_y  :> pix_y
  );

  text_display display<@vga_clock,!vga_reset>(
	pix_x      <: pix_x,
	pix_y      <: pix_y,
	pix_active <: active,
	pix_vblank <: vblank,
	pix_red    :> vga_r,
	pix_green  :> vga_g,
	pix_blue   :> vga_b
  );

  // unused pins
  spi_miso := 1bz;
  avr_rx := 1bz;
  spi_channel := 4bzzzz;

  // forever
  while (1) {
  
    while (vblank == 1) { }
    while (vblank == 0) { }

    led = ~led;
    
  }
}

