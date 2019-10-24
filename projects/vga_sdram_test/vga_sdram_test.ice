// SDRAM controller
import('verilog/sdram.v')

// SDRAM simulator
append('verilog/mt48lc32m8a2.v')
import('verilog/simul_sdram.v')

// Frame buffer row
import('verilog/dual_frame_buffer_row.v')

// VGA driver
$include('../common/vga.ice')

// ------------------------- 

// 320x240
algorithm frame_display(
  input  uint10 vga_x,
  input  uint10 vga_y,
  input  uint1  vga_active,
  output uint4  vga_r,
  output uint4  vga_g,
  output uint4  vga_b,
  output uint10 pixaddr,
  input  uint24 pixdata_r,
  output uint1  display_row_busy
) {

  uint24 pixel = 0;
  uint9  pix_i = 0;
  uint8  pix_j = 0;
  uint2  sub_j = 0;

 
  // ---------- show time!

  display_row_busy = 0;
  
  pixaddr = 0;
  
  while (1) {
    
    vga_r = 0;
    vga_g = 0;
    vga_b = 0;

    if (vga_active) {

      // display
      if (pix_j < 200) {
        pixel = pixdata_r;
        vga_r = pixel;
        vga_g = pixel >> 8;
        vga_b = pixel >> 16;
      }
      
      // compute pix_i
      pix_i = vga_x >> 1;
      
      if (vga_x == 639) { // end of row
        
        // increment pix_j
        sub_j = sub_j + 1;
        if (sub_j == 2) {
          sub_j = 0;
          if (pix_j < 200) {
            // increment row
            pix_j = pix_j + 1;
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
    display_row_busy = (pix_j & 1);

    // next address to read in row is pix_i
    pixaddr = pix_i;
    if (display_row_busy) {
      pixaddr = pixaddr + 320;
    }

  }
}

// ------------------------- 

algorithm sdram_switcher(

  input  uint23 saddr0,
  input  uint1  srw0,
  input  uint32 sd_in0,
  output uint32 sd_out0,
  output uint1  sbusy0,
  input  uint1  sin_valid0,
  output uint1  sout_valid0,
  
  input  uint23 saddr1,
  input  uint1  srw1,
  input  uint32 sd_in1,
  output uint32 sd_out1,
  output uint1  sbusy1,
  input  uint1  sin_valid1,
  output uint1  sout_valid1,

  output uint23 saddr,
  output uint1  srw,
  output uint32 sd_in,
  input  uint32 sd_out,
  input  uint1  sbusy,
  output uint1  sin_valid,
  input  uint1  sout_valid
) {
	
  // defaults
  /*
  sin_valid   := 0;
  sout_valid0 := 0;
  sout_valid1 := 0;
  sbusy0      := sbusy;
  sbusy1      := sbusy;
  */
  
  while (1) {

    // if output available, transmit
    // (it does not matter who requested it,
    //  they cannot both be waiting for it)
    if (sout_valid) {
      sout_valid0 = 1;
      sout_valid1 = 1;
      sd_out0     = sd_out;
      sd_out1     = sd_out;
    } else {
      sout_valid0 = 0;
      sout_valid1 = 0;
	}

    // check 0 first (higher priority)
    if (sin_valid0) {
      sbusy1     = 1; // other is busy
      // set read/write
      sin_valid  = 1;
      saddr      = saddr0;
      srw        = srw0;
      sd_in      = sd_in0;
    } else {   
	  sbusy1     = sbusy;
      // check 1 next, if not set to busy
      if (sin_valid1) {
        sbusy0     = 1; // other is busy
        // set read/write
        sin_valid  = 1;
        saddr      = saddr1;
        srw        = srw1;
        sd_in      = sd_in1;
      } else {
		sin_valid   = 0;
        sbusy0      = sbusy;
	  }
    }

  } // end of while

}

// ------------------------- 

algorithm frame_buffer_row_updater(
  output uint23 saddr,
  output uint1  srw,
  output uint32 sdata_in,
  input  uint32 sdata_out,
  input  uint1  sbusy,
  output uint1  sin_valid,
  input  uint1  sout_valid,
  output uint10 pixaddr,
  output uint24 pixdata_w,
  output uint1  pixwenable,
  input  uint1  row_busy,
  input  uint1  vsync
)
{
  // frame update counters
  uint10 next  = 0;
  uint10 count = 0;
  uint8  row   = 1; // 1 .. 199 .. 0 (start with 1, 0 loads after 199)
  uint1  working_row = 1;
  
  srw = 0;  // read

  while(1) {

    // wait during vsync
    while (vsync) { }
    row         = 1;
    working_row = 1;
  
    // wait while the busy row is the working row
    while (working_row == row_busy) { }

    // read row from SDRAM to frame buffer
    //    
    // NOTE: here we assume this can be done fast enough such that row_busy
    //       will not change mid-course ... will this be true? 
    //       in any case the display cannot wait, so apart from error
    //       detection there is no need for a sync mechanism
    next = 0;
    if (working_row) {
      next = 320;
    }
    count = 0;
    while (count < 320) {
	
      if (sbusy == 0) {        // not busy?
        saddr       = count + (row << 8) + (row << 6); // address to read from (count + row * 320)
        sin_valid   = 1;         // go ahead!      
     ++:
	    sin_valid   = 0;
        while (sout_valid == 0) {  } // wait for value
        // write to selected frame buffer row
        pixdata_w   = sdata_out; // data to write
        pixwenable  = 1;
        pixaddr     = next;     // address to write
     ++: // wait one cycle
        pixwenable  = 0; // write done
        // next
        next        = next  + 1;
        count       = count + 1;
      }

    }
    // change working row
    working_row = 1 - working_row;
    row = row + 1;
	  // wrap back to 0 after 199
    if (row == 200) {
      row = 0;
    }
  }

}

// ------------------------- 

algorithm frame_drawer(
  output uint23 saddr,
  output uint1  srw,
  output uint32 sdata_in,
  input  uint32 sdata_out,
  input  uint1  sbusy,
  output uint1  sin_valid,
  input  uint1  sout_valid,
  input  uint1  vsync
) {

  uint16 shift = 0;

  subroutine bands(
    reads   shift,
    reads   sbusy,
    writes  sdata_in,
    writes  saddr,
    writes  sin_valid
  )
    uint9  pix_x = 0;
    uint8  pix_y = 0;  
    
    pix_y = 0;  
    while (pix_y < 200) {
      pix_x  = 0;
      while (pix_x < 320) {
        // write to sdram
        while (1) {          
          if (sbusy == 0) {        // not busy?
            sdata_in  = ((pix_x + shift) & 255) + (pix_y << 8);
            saddr     = pix_x + (pix_y << 8) + (pix_y << 6); // * 320
            sin_valid = 1; // go ahead!
		++:
		    sin_valid = 0;
            break;
          }
        } // write occurs during loop cycle      
        pix_x = pix_x + 1;
      }
      pix_y = pix_y + 1;
    }
  return;
  
  srw   = 1;  // write

  while (1) {

    // wait for vsync
    while (vsync) {}

    /// TODO NOTE: while (!vsync) {} should work here ...? to investigate
    
    // draw a frame
    () <- bands <- ();
	
    // increment shift    
    shift = shift + 1;
    
  }

}

// ------------------------- 

algorithm main(
  output uint4 vga_r,
  output uint4 vga_g,
  output uint4 vga_b,
  output uint1 vga_hs,
  output uint1 vga_vs
) {

// --- VGA

uint1  vga_active = 0;
uint1  vga_vblank = 0;
uint10 vga_x  = 0;
uint10 vga_y  = 0;

vga vga_driver(
	vga_r  <: vga_r,
	vga_g  <: vga_g,
	vga_b  <: vga_b,
    vga_hs :> vga_hs,
	vga_vs :> vga_vs,
	active :> vga_active,
	vblank :> vga_vblank,
	vga_x  :> vga_x,
	vga_y  :> vga_y
);

// --- SDRAM

uint23 saddr       = 0;
uint1  srw         = 0;
uint32 sdata_in    = 0;
uint32 sdata_out   = 0;
uint1  sbusy       = 0;
uint1  sin_valid   = 0;
uint1  sout_valid  = 0;

uint1  sdram_cle   = 0;
uint1  sdram_dqm   = 0;
uint1  sdram_cs    = 0;
uint1  sdram_we    = 0;
uint1  sdram_cas   = 0;
uint1  sdram_ras   = 0;
uint2  sdram_ba    = 0;
uint13 sdram_a     = 0;
uint8  sdram_dq    = 0;

simul_sdram simul(
  sdram_clk <: clock,
  <:auto:>
);

sdram memory(
  clk       <: clock,
  rst       <: reset,
  addr      <: saddr,
  rw        <: srw,
  data_in   <: sdata_in,
  data_out  :> sdata_out,
  busy      :> sbusy,
  in_valid  <: sin_valid,
  out_valid :> sout_valid,
  <:auto:> // TODO FIXME only way to bind inout? introduce <:> ?
);

// --- SDRAM switcher

uint23 saddr0      = 0;
uint1  srw0        = 0;
uint32 sd_in0      = 0;
uint32 sd_out0     = 0;
uint1  sbusy0      = 0;
uint1  sin_valid0  = 0;
uint1  sout_valid0 = 0;

uint23 saddr1      = 0;
uint1  srw1        = 0;
uint32 sd_in1      = 0;
uint32 sd_out1     = 0;
uint1  sbusy1      = 0;
uint1  sin_valid1  = 0;
uint1  sout_valid1 = 0;

sdram_switcher sd_switcher(
  saddr      :> saddr,
  srw        :> srw,
  sd_in      :> sdata_in,
  sd_out     <: sdata_out,
  sbusy      <: sbusy,
  sin_valid  :> sin_valid,
  sout_valid <: sout_valid,

  saddr0      <: saddr0,
  srw0        <: srw0,
  sd_in0      <: sd_in0,
  sd_out0     :> sd_out0,
  sbusy0      :> sbusy0,
  sin_valid0  <: sin_valid0,
  sout_valid0 :> sout_valid0,

  saddr1      <: saddr1,
  srw1        <: srw1,
  sd_in1      <: sd_in1,
  sd_out1     :> sd_out1,
  sbusy1      :> sbusy1,
  sin_valid1  <: sin_valid1,
  sout_valid1 :> sout_valid1
);

// --- Frame buffer row memory

  uint16 pixaddr_r = 0;
  uint16 pixaddr_w = 0;
  uint4  pixdata_r = 0;
  uint4  pixdata_w = 0;
  uint1  pixwenable  = 0;

  dual_frame_buffer_row fbr(
    rclk    <: clock,
    raddr   <: pixaddr_r,
    rdata   :> pixdata_r,
    wclk    <: clock,
    waddr   <: pixaddr_w,
    wdata   <: pixdata_w,
    wenable <: pixwenable
  );

// --- Display

  uint1 display_row_busy = 0;

  frame_display display(
    pixaddr   :> pixaddr_r,
    pixdata_r <: pixdata_r,
    display_row_busy :> display_row_busy,
    <:auto:>
  );

// --- Frame buffer row updater
  frame_buffer_row_updater fbrupd(
    pixaddr    :> pixaddr_w,
    pixdata_w  :> pixdata_w,
    pixwenable :> pixwenable,
    row_busy   <: display_row_busy,
    vsync      <: vga_vblank,
    saddr      :> saddr0,
    srw        :> srw0,
    sdata_in   :> sd_in0,
    sdata_out  <: sd_out0,
    sbusy      <: sbusy0,
    sin_valid  :> sin_valid0,
    sout_valid <: sout_valid0
  );
 
// --- Frame drawer
  frame_drawer drawer(
    vsync      <: vga_vblank,
    saddr      :> saddr1,
    srw        :> srw1,
    sdata_in   :> sd_in1,
    sdata_out  <: sd_out1,
    sbusy      <: sbusy1,
    sin_valid  :> sin_valid1,
    sout_valid <: sout_valid1  
  );

  uint8 frame  = 0;

  // ---------- let's go

  // start the switcher
  sd_switcher <- ();
  
  // start the frame drawer
  drawer <- ();
  
  // start the frame buffer row updater
  fbrupd <- ();
 
  // start the display driver
  display <- (); 

  // we count a number of frames and stop

  while (frame < 5) {
  
    while (vga_vblank == 1) { }
	$display("vblank off");
    
	while (vga_vblank == 0) { }
    $display("vblank on");
	
    frame = frame + 1;

  }

}

