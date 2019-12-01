// SL 2019-10

// ------------------------- 

// 320x200
// actual resolution is     640x480
// we divide by two down to 320x240
// and the use rows 1 to 200 (as opposed to 0 to 199)
// the first row (0) is used to pre-load row 1
algorithm frame_display(
  input   uint10 vga_x,
  input   uint10 vga_y,
  input   uint1  vga_active,
  output! uint4  vga_r,
  output! uint4  vga_g,
  output! uint4  vga_b,
  output! uint10 pixaddr,
  input   uint32 pixdata_r,
  output! uint1  row_busy
) <autorun> {
  uint8  palidx = 0;
  uint8  pix_j  = 0;
  uint2  sub_j  = 0;
  uint9  pix_a  = 0;

  vga_r := 0;
  vga_g := 0;
  vga_b := 0;
 
  // ---------- show time!

  while (1) {
    
    row_busy = 1;
  
    if (row_busy) {
      pixaddr = (320) >> 2;
    } else {
      pixaddr = (  0) >> 2;
    }
  
    if (vga_active) {

      // display
	    // -> screen row 0 is skipped as we preload row 0, we draw rows 1-200
	    //    the row loader loads row   0 for display in screen row   1
	    //    ...            loads row 199 for display in screen row 200
      if (pix_j > 0 && pix_j <= 200) {		
		    palidx = pixdata_r >> (((vga_x >> 1)&3)<<3);
		    switch (palidx) {
        case 0: {
          vga_r  = 0;
          vga_g  = 0;
          vga_b  = 0;
		    }
        case 1: {
          vga_r  = 15;
          vga_g  = 0;
          vga_b  = 0;
		    }
        case 2: {
          vga_r  = 0;
          vga_g  = 15;
          vga_b  = 0;
		    }
        case 3: {
          vga_r  = 0;
          vga_g  = 0;
          vga_b  = 15;
		    }
        default: {
          vga_r  = palidx;
          vga_g  = palidx;
          vga_b  = palidx;
		    }
        }
      }
      if (vga_x == 639) { // end of row
        
        // increment pix_j
        sub_j = sub_j + 1;
        if (sub_j == 2) {
          sub_j = 0;
          if (pix_j <= 200) {
            // increment row
            pix_j = pix_j + 1;
          } else {
			      pix_j = 201;
		      }
        }
		
        if (vga_y == 479) {
          // end of frame
          sub_j = 0;
          pix_j = 0;          
        }
      }
      
    } 

    // busy row
    if (pix_j < 200) {		
      row_busy = ~(pix_j&1);
    }

    // prepare next read
    // note the use of vga_x + 1 to trigger 
	  // read one clock step ahead so that result 
    // is avail right on time
    if (vga_x < 639) {
      pix_a = ((vga_x+1) >> 1);
	  } else {
	    pix_a = 0;
	  }
    if (row_busy) {
      pixaddr = ((pix_a) + 320) >> 2;  
    } else {
      pixaddr = (pix_a) >> 2;
	  }

  }
}

// ------------------------- 

algorithm sdram_switcher(
  
  input uint1    select,

  input   uint23 saddr0,
  input   uint2  swbyte_addr0,
  input   uint1  srw0,
  input   uint32 sd_in0,
  output! uint32 sd_out0,
  output! uint1  sbusy0,
  input   uint1  sin_valid0,
  output! uint1  sout_valid0,
  
  input   uint23 saddr1,
  input   uint2  swbyte_addr1,
  input   uint1  srw1,
  input   uint32 sd_in1,
  output! uint32 sd_out1,
  output! uint1  sbusy1,
  input   uint1  sin_valid1,
  output! uint1  sout_valid1,

  output! uint23 saddr,
  output! uint2  swbyte_addr,
  output! uint1  srw,
  output! uint32 sd_in,
  input   uint32 sd_out,
  input   uint1  sbusy,
  output! uint1  sin_valid,
  input   uint1  sout_valid
  
) {
	
  uint1 active = 0;
  
  while (1) {
  
    // switch only when there is no activity
    if (  sbusy      == 0 
       && select     != active
       && sin_valid0 == 0
       && sin_valid1 == 0) {
      active = select;
    }  

    if (active) {
	    saddr       = saddr0;
      swbyte_addr = swbyte_addr0;
	    srw         = srw0;
	    sd_in       = sd_in0;
	    sd_out0     = sd_out;
	    sbusy0      = sbusy;
	    sin_valid   = sin_valid0;
	    sout_valid0 = sout_valid;
	    sbusy1      = 1;
    } else {
	    saddr       = saddr1;
      swbyte_addr = swbyte_addr1;
	    srw         = srw1;
	    sd_in       = sd_in1;
	    sd_out1     = sd_out;
	    sbusy1      = sbusy;
	    sin_valid   = sin_valid1;
	    sout_valid1 = sout_valid;
	    sbusy0      = 1;
    }
  }  
}

// ------------------------- 

algorithm frame_buffer_row_updater(
  output  uint23 saddr,
  output  uint1  srw,
  output  uint32 sdata_in,
  input   uint32 sdata_out,
  input   uint1  sbusy,
  output  uint1  sin_valid,
  input   uint1  sout_valid,
  output! uint10 pixaddr,
  output! uint32 pixdata_w,
  output! uint1  pixwenable,
  input   uint1  row_busy,
  input   uint1  vsync,
  output  uint1  working
)
{
  // frame update counters
  uint10 next  = 0;
  uint10 count = 0;
  uint8  row   = 0; // 0 .. 200 (0 loads 1, but 0 is not displayed, we display 1 - 200)
  uint1  working_row = 0;
  uint1  row_busy_filtered = 0;
  uint1  vsync_filtered    = 0;

  sin_valid   := 0; // maintain low (pulses high when needed)
  row_busy_filtered ::= row_busy;
  vsync_filtered    ::= vsync;
  
  working = 0;  // not working yet  
  srw     = 0;  // read

  while(1) {

    // not working for now
    working       = 0;

    // wait during vsync or while the busy row is the working row
    while (vsync_filtered || (working_row == row_busy_filtered)) { 
		  if (vsync_filtered) { // vsync implies restarting the row counter
			  row         = 0;
			  working_row = 0;
		  }
	  }

    // working again!
	  working = 1;

    // read row from SDRAM to frame buffer
    //    
    // NOTE: here we assume this can be done fast enough such that row_busy
    //       will not change mid-course ... will this be true? 
    //       in any case the display cannot wait, so apart from error
    //       detection there is no need for a sync mechanism    
    if (working_row) {
      next = (320 >> 2);
    } else {
	    next = 0;
	  }
    count = 0;
    pixwenable  = 1;
    while (count < (320 >> 2)) {
	
      if (sbusy == 0) {        // not busy?
        saddr       = count + (((row << 8) + (row << 6)) >> 2); // address to read from (count + row * 320 / 4)
        sin_valid   = 1;         // go ahead!      
        while (sout_valid == 0) {  } // wait for value
        // write to selected frame buffer row
        pixdata_w   = sdata_out; // data to write
        pixaddr     = next;     // address to write
        // next
        next        = next  + 1;
        count       = count + 1;
      }

    }
    
    pixwenable  = 0; // write done
	  if (row < 199) {
      // change working row
      working_row = ~working_row;
      row = row + 1;
	  }
  }

}

// ------------------------- 
