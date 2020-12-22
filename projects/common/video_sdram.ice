// SL 2019-10
//
//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

// ------------------------- 

// 320x200
// Actual resolution is      640x480
//   we divide by 2   down to 320x240
// and the use rows 1 to 200 (as opposed to 0 to 199)
// the first row (0) is used to pre-load row 1
algorithm frame_display(
  input   uint11   video_x,
  input   uint10   video_y,
  input   uint1    video_active,
  output! uint8    video_r,
  output! uint8    video_g,
  output! uint8    video_b,
  output! uint10   pixaddr0,
  input   uint128  pixdata0_r,
  output! uint10   pixaddr1,
  input   uint128  pixdata1_r,
  output! uint1    row_busy
) <autorun> {

  uint24 palette[] = {
    // palette from pre-processor table
$$  for i=1,256 do
    $palette[i]$,
$$  end
  };  
  uint8  palidx = 0;
  uint8  pix_j  = 0;
  uint2  sub_j  = 0;
  uint9  pix_a  = 0;
  uint24 color  = 0;

  uint9 sub_a := {(video_x>>1) & 6d15,3b000};

  video_r := 0;
  video_g := 0;
  video_b := 0;

  // ---------- show time!

  row_busy = 1; // initally reading from row 1

  while (1) {
    
    pixaddr0 = 0;
    pixaddr1 = 0;
  
    if (video_active) {

      // display
	    // -> screen row 0 is skipped as we preload row 0, we draw rows 1-200
	    //    the row loader loads row   0 for display in screen row   1
	    //    ...            loads row 199 for display in screen row 200
      if (pix_j > 0 && pix_j <= 200) {
        if (row_busy) {
          palidx = pixdata1_r[sub_a,8];
        } else {
          palidx = pixdata0_r[sub_a,8];
        }
        color    = palette[palidx];
$$if HDMI then        
        video_r  = color[ 0,8];
        video_g  = color[ 8,8];
        video_b  = color[16,8];
$$else
        video_r  = color[ 0,8] >> $8-color_depth$;
        video_g  = color[ 8,8] >> $8-color_depth$;
        video_b  = color[16,8] >> $8-color_depth$;
$$end        
      }
      if (video_x == 639) { // end of row
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
		
        if (video_y == 479) {
          // end of frame
          sub_j = 0;
          pix_j = 0;          
        }
      }
      
    } 

    // busy row
    if (pix_j < 200) {		
      row_busy = ~(pix_j[0,1]);
    }

    // prepare next read
    // note the use of video_x + 1 to trigger 
	  // read one clock step ahead so that result 
    // is avail right on time
    if (video_x < 639) {
		  pix_a = ((video_x+1) >> 1);
	  } else {
	    pix_a = 0;
	  }
    
    pixaddr0 = pix_a>>4;
    pixaddr1 = pix_a>>4;

  }

}

// ------------------------- 

algorithm frame_buffer_row_updater(
  sdram_user       sd,
  output! uint10   pixaddr0,
  output! uint128  pixdata0_w,
  output! uint1    pixwenable0,
  output! uint10   pixaddr1,
  output! uint128  pixdata1_w,
  output! uint1    pixwenable1,
  input   uint1    row_busy,
  input   uint1    vsync,
  output  uint1    working,
  input   uint1    fbuffer
) <autorun> {
  // frame update counters
  uint9  count             = 0;
  uint8  row               = 0; // 0 .. 200 (0 loads 1, but 0 is not displayed, we display 1 - 200)
  uint1  working_row       = 0; // parity of row in which we write
  uint1  row_busy_filtered = 0;
  uint1  vsync_filtered    = 0;
  uint1  fbuffer_filtered  = 0;

  sd.in_valid       := 0; // maintain low (pulses high when needed)
  
  row_busy_filtered ::= row_busy;
  vsync_filtered    ::= vsync;
  fbuffer_filtered  ::= fbuffer;
  
  always {
    // writing/reading on buffers
    if (row_busy_filtered) {
      pixwenable0 = 1; // write 0
      pixwenable1 = 0; // read  1
    } else {
      pixwenable0 = 0; // read  0
      pixwenable1 = 1; // write 1
    }  
  }
  
  working = 0;  // not working  
  sd.rw   = 0;  // read

  while(1) {

    // not working for now
    working = 0;

    // wait during vsync or while the busy row is the working row
    while (vsync_filtered || (working_row == row_busy_filtered)) { 
		  if (vsync_filtered) { // vsync implies restarting the row counter
			  row         = 0;
			  working_row = 0;
		  }
	  }

    // working again!
	  working = 1;
    // working_row (in which we write) is now != busy_row (which is read for display)

    // read row from SDRAM into frame row buffer
    //    
    // NOTE: here we assume this can be done fast enough such that row_busy
    //       will not change mid-course ... will this be true? 
    //       in any case the display cannot wait, so apart from error
    //       detection there is no need for a sync mechanism    
    count = 0;
    while (count < $320//16$) { // we read 16 bytes at once
	
      // address to read from (count + row * 320)        
      sd.addr      = {1b0,fbuffer_filtered,24b0} | (count<<4) | (row << 9); 
      sd.in_valid  = 1;             // go ahead!      
      while (sd.done == 0) { }      // wait for value
      // __display("<read %x>",sd.data_out);
      pixdata0_w   = sd.data_out;   // data to write
      pixaddr0     = count;         // address to write
      pixdata1_w   = sd.data_out;   // data to write
      pixaddr1     = count;         // address to write        
      // next
      count        = count + 1;

    }

    // change working row
    working_row = ~working_row;
	  if (row < 199) {
      row = row + 1;
	  } else {    
      row = 0;
    }
  }

}

// ------------------------- 
