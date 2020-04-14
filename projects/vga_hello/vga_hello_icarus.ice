// -------------------------

// Text buffer
import('../common/text_buffer.v')

// VGA driver
$include('../common/vga.ice')

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
  
  $include('../common/font.ice')
   
  // ---------- text display

  uint8  text_i   = 0;
  uint7  text_j   = 0;
  uint3  letter_i = 0;
  uint4  letter_j = 0;
  uint1  pixel    = 0;
  uint12 addr     = 0;

  uint16 next     = 0;

  uint11 str_x    = 10;
  uint10 str_y    = 10;

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
	  ) {
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
  }
  
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
	  str_y = str_y + 2;

      // wait until vblank is over
	  while (pix_vblank == 1) { }

	  // display frame
	  while (pix_vblank == 0) {

        pix_green = pix_y;

		if (letter_j < 8) {
		  letter_i = pix_x & 7;
		  addr     = letter_i + (letter_j << 3) + (txtdata_r << 6);
		  pixel    = letters[ addr ];
		  if (pixel == 1) {
        pix_red   = 15;
        pix_green = 15;
        pix_blue  = 15;
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
  output! uint1 video_clock,
  output! uint4 video_r,
  output! uint4 video_g,
  output! uint4 video_b,
  output! uint1 video_hs,
  output! uint1 video_vs
) {

  uint1  active = 0;
  uint1  vblank = 0;
  uint10 pix_x  = 0;
  uint10 pix_y  = 0;

  vga vga_driver(
    vga_hs :> video_hs,
	  vga_vs :> video_vs,
	  active :> active,
	  vblank :> vblank,
	  vga_x  :> pix_x,
	  vga_y  :> pix_y
  );

  text_display display(
	  pix_x      <: pix_x,
	  pix_y      <: pix_y,
	  pix_active <: active,
	  pix_vblank <: vblank,
	  pix_red    :> video_r,
	  pix_green  :> video_g,
	  pix_blue   :> video_b
  );


  uint8 frame  = 0;

  // vga clock is directly the input clock
  video_clock := clock;

  // we count a number of frames and stop
  while (frame < 2) {
  
    while (vblank == 1) { }
	  $display("vblank off");
    while (vblank == 0) { }
    $display("vblank on");
    frame = frame + 1;

  }
}

