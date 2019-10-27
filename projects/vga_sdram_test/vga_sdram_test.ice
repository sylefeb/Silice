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
  input   uint10 vga_x,
  input   uint10 vga_y,
  input   uint1  vga_active,
  output! uint4  vga_r,
  output! uint4  vga_g,
  output! uint4  vga_b,
  output! uint10 pixaddr,
  input   uint32 pixdata_r,
  output! uint1  display_row_busy
) {
  uint8  palidx = 0;
  uint8  pix_j  = 0;
  uint2  sub_j  = 0;
  uint9  pix_a  = 0;
 
  // ---------- show time!

  display_row_busy = 0;
  
  if (display_row_busy) {
    pixaddr = (320) >> 2;
  } else {
    pixaddr = (  0) >> 2;
  }
  
  while (1) {
    
    vga_r = 0;
    vga_g = 0;
    vga_b = 0;

    if (vga_active) {

      // display
      if (pix_j < 200) {
		
		palidx = pixdata_r >> (((vga_x >> 1)&3)<<3);
        vga_r  = palidx;
        vga_g  = palidx;
        vga_b  = palidx;
      }
      
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
    display_row_busy = (pix_j&1);

    // prepare next read
    // note the use of vga_x + 1 to trigger 
	// read one clock step ahead so that result 
    // is avail right on time
    if (vga_x < 639) {
      pix_a = ((vga_x+1) >> 1);
	} else {
	  pix_a = 0;
	}
    if (display_row_busy) {
      pixaddr = ((pix_a) + 320) >> 2;  
    } else {
      pixaddr =  (pix_a) >> 2;
	}

  }
}

// ------------------------- 

algorithm sdram_switcher(
  
  input uint1    select,

  input   uint23 saddr0,
  input   uint1  srw0,
  input   uint32 sd_in0,
  output! uint32 sd_out0,
  output! uint1  sbusy0,
  input   uint1  sin_valid0,
  output! uint1  sout_valid0,
  
  input   uint23 saddr1,
  input   uint1  srw1,
  input   uint32 sd_in1,
  output! uint32 sd_out1,
  output! uint1  sbusy1,
  input   uint1  sin_valid1,
  output! uint1  sout_valid1,

  output! uint23 saddr,
  output! uint1  srw,
  output! uint32 sd_in,
  input   uint32 sd_out,
  input   uint1  sbusy,
  output! uint1  sin_valid,
  input   uint1  sout_valid
  
) {
	
  while (1) {
    if (select) {
	  saddr       = saddr0;
	  srw         = srw0;
	  sd_in       = sd_in0;
	  sd_out0     = sd_out;
	  sbusy0      = sbusy;
	  sin_valid   = sin_valid0;
	  sout_valid0 = sout_valid;
	  sbusy1      = 1;	  
    } else {
	  saddr       = saddr1;
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
  uint8  row   = 1; // 1 .. 199 .. 0 (start with 1, 0 loads after 199)
  uint1  working_row = 1;

  sin_valid   := 0; // maintain low (pulses high when needed)
  
  working = 0;  // not working yet  
  srw     = 0;  // read

  while(1) {

    // not working for now
    working       = 0;

    // wait during vsync
    while (vsync) { 
      row         = 1;
      working_row = 1;
	}
 
    // wait while the busy row is the working row
    while (working_row == row_busy) { }

    // working again!
	working = 1;

    // read row from SDRAM to frame buffer
    //    
    // NOTE: here we assume this can be done fast enough such that row_busy
    //       will not change mid-course ... will this be true? 
    //       in any case the display cannot wait, so apart from error
    //       detection there is no need for a sync mechanism
    next = 0;
    if (working_row) {
      next = (320 >> 2);
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
    // change working row
    working_row = ~ working_row;
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
  output uint1  sin_valid,
  input  uint32 sdata_out,
  input  uint1  sbusy,
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
    uint9  pix_x   = 0;
    uint8  pix_y   = 0;
    uint8  pix_palidx = 0;
    uint32 fourpix = 0; // accumulate four 8 bit pixels in 32 bits word
	
    pix_y = 0;  
    while (pix_y < 200) {
      pix_x  = 0;
      while (pix_x < 320) {
		
		// compute pixel palette index
		pix_palidx = pix_x + shift;
		fourpix    = fourpix | (pix_palidx << ((pix_x&3)<<3));
		
		if ((pix_x&3) == 3) {
          // write to sdram
          while (1) {          
            if (sbusy == 0) {        // not busy?
              sdata_in  = fourpix;
              saddr     = (pix_x + (pix_y << 8) + (pix_y << 6)) >> 2; // * 320 / 4
              sin_valid = 1; // go ahead!
              break;
            }
          }
		  // reset accumulator
		  fourpix = 0;		  
		}
		
        pix_x = pix_x + 1;
      }
      pix_y = pix_y + 1;
    }
  return;
  
  sin_valid   := 0; // maintain low (pulses high when needed)

  srw   = 1;  // write

  while (1) {

    // draw a frame
	$display("drawing ...");
    () <- bands <- ();
	$display("done.");
	
    // increment shift    
    shift = shift + 1;
    
    // wait for vsync
    while (vsync == 1) {}
    while (vsync == 0) {}

  }
}

// ------------------------- 

// PLL for simulation
/*
NOTE: sdram_clock cannot use a normal output as this would mean sampling
      a register tracking clock using clock itself; this lead to a race
	  condition, see https://stackoverflow.com/questions/58563770/unexpected-simulation-behavior-in-iverilog-on-flip-flop-replicating-clock-signal
	  
*/
algorithm pll(
  output  uint1 vga_clock,
  output  uint1 vga_reset,
  output! uint1 sdram_clock,
  output! uint1 sdram_reset
) <autorun>
{
  uint3 counter = 0;
  uint8 trigger = 8b11111111;
  
  sdram_clock   := clock;
  sdram_reset   := reset;
  
  vga_clock     := counter[2,1];
  vga_reset     := (trigger > 0);
  
  while (1) {
	counter = counter + 1;
	trigger = trigger >> 1;
  }
}

// ------------------------- 

algorithm main(
  output! uint1 vga_clock,
  output! uint4 vga_r,
  output! uint4 vga_g,
  output! uint4 vga_b,
  output! uint1 vga_hs,
  output! uint1 vga_vs
) <@sdram_clock> {

// --- PLL

uint1 vga_reset   = 0;
uint1 sdram_clock = 0;
uint1 sdram_reset = 0;

pll clockgen<@clock,!reset>(
  vga_clock   :> vga_clock,
  vga_reset   :> vga_reset,
  sdram_clock :> sdram_clock,
  sdram_reset :> sdram_reset
);

// --- VGA

uint1  vga_active = 0;
uint1  vga_vblank = 0;
uint10 vga_x  = 0;
uint10 vga_y  = 0;

vga vga_driver<@vga_clock,!vga_reset>(
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

simul_sdram simul<@sdram_clock,!sdram_reset>(
  sdram_clk <: clock,
  <:auto:>
);

sdram memory<@sdram_clock,!sdram_reset>(
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

uint1  select      = 0;

sdram_switcher sd_switcher<@sdram_clock,!sdram_reset>(
  select     <: select,

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
// dual clock crosses from sdram to vga

  uint16 pixaddr_r = 0;
  uint16 pixaddr_w = 0;
  uint32 pixdata_r = 0;
  uint32 pixdata_w = 0;
  uint1  pixwenable  = 0;

  dual_frame_buffer_row fbr(
    rclk    <: vga_clock,
    wclk    <: sdram_clock,
    raddr   <: pixaddr_r,
    rdata   :> pixdata_r,
    waddr   <: pixaddr_w,
    wdata   <: pixdata_w,
    wenable <: pixwenable
  );

// --- Display

  uint1 display_row_busy = 0;

  frame_display display<@vga_clock,!vga_reset>(
    pixaddr   :> pixaddr_r,
    pixdata_r <: pixdata_r,
    display_row_busy :> display_row_busy,
	vga_x <: vga_x,
	vga_y <: vga_y,
    <:auto:>
  );

// --- Frame buffer row updater
  frame_buffer_row_updater fbrupd<@sdram_clock,!sdram_reset>(
    working    :> select,
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
  frame_drawer drawer<@sdram_clock,!sdram_reset>(
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
  uint8 iter   = 0;

  // ---------- let's go

  // -> wait for vga_reset
  while (vga_reset == 0) {}
  while (vga_reset == 1) {}

  // start the switcher
  sd_switcher <- ();
  
  // start the frame drawer
  drawer <- ();
   
  // start the frame buffer row updater
  fbrupd <- ();
 
  // start the display driver
  // -> call
  // we lengthen the call, due to it running on a slower clock domains
  iter = 0;
  while (iter < 8) { 
    display <- ();
	iter = iter + 1;
  }

  // we count a number of frames and stop
  while (frame < 5) {
  
    while (vga_vblank == 1) { }
	$display("vblank off");
    
	while (vga_vblank == 0) { }
    $display("vblank on");
	
    frame = frame + 1;

  }

}

