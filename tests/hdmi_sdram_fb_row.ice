import('reset_conditioner.v')

// UART
append('uart_rx.v')
append('uart_tx.v')
append('spi_slave.v')
append('cclk_detector.v')

import ('avr_interface.v')

// SDRAM
import('sdram.v')

// HDMI
append('serdes_n_to_1.v')
append('simple_dual_ram.v')
append('tmds_encoder.v')
append('async_fifo.v')
append('fifo_2x_reducer.v')
append('dvi_encoder.v')

import('clk_wiz.v')
import('hdmi_encoder.v')

// Frame buffer row
import('dual_frame_buffer_row.v')

// ------------------------- 

algorithm frame_display(
  input  uint11 hdmi_x,
  input  uint10 hdmi_y,
  input  uint1  hdmi_active,
  output uint8  hdmi_red,
  output uint8  hdmi_green,
  output uint8  hdmi_blue,
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
    
    hdmi_red   = 0;
    hdmi_green = 0;
    hdmi_blue  = 0;

    if (hdmi_active) {

      // display through hdmi
      if (pix_j < 200) {
        pixel      = pixdata_r;
        hdmi_red   = pixel;
        hdmi_green = pixel >> 8;
        hdmi_blue  = pixel >> 16;
      }
      
      // compute pix_i
      pix_i = hdmi_x >> 2;
      
      if (hdmi_x == 1279) { // end of row
        
        // increment pix_j
        sub_j = sub_j + 1;
        if (sub_j == 3) {
          sub_j = 0;
          if (pix_j < 200) {
            // increment row
            pix_j = pix_j + 1;
          }
        }
        if (hdmi_y == 719) {
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

  input  uint22 saddr0,
  input  uint1  srw0,
  input  uint32 sd_in0,
  output uint32 sd_out0,
  output uint1  sbusy0,
  input  uint1  sin_valid0,
  output uint1  sout_valid0,
  
  input  uint22 saddr1,
  input  uint1  srw1,
  input  uint32 sd_in1,
  output uint32 sd_out1,
  output uint1  sbusy1,
  input  uint1  sin_valid1,
  output uint1  sout_valid1,

  output uint22 saddr,
  output uint1  srw,
  output uint32 sd_in,
  input  uint32 sd_out,
  input  uint1  sbusy,
  output uint1  sin_valid,
  input  uint1  sout_valid
) {
  
  // defaults
  sin_valid   := 0;
  sout_valid0 := 0;
  sout_valid1 := 0;
  sbusy0      := sbusy;
  sbusy1      := sbusy;
  
  while (1) {

    // if output available, transmit
    // (it does not matter who requested it,
    //  they cannot both be waiting for it)
    if (sout_valid) {
      sout_valid0 = 1;
      sout_valid1 = 1;
      sd_out0     = sd_out;
      sd_out1     = sd_out;
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
      // check 1 next, if not set to busy
      if (sin_valid1) {
        sbusy0     = 1; // other is busy
        // set read/write
        sin_valid  = 1;
        saddr      = saddr1;
        srw        = srw1;
        sd_in      = sd_in1;
      }      
    }
    
  } // end of while
  
}

// ------------------------- 

algorithm frame_buffer_row_updater(
  output uint22 saddr,
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
  // for subroutine bands    TODO: allow variable declarations in subroutine?
  uint9  pix_x = 0;
  uint8  pix_y = 0;  
  uint16 shift = 0;
  
  // frame update counters
  uint10 next  = 0;
  uint10 count = 0;
  uint8  row   = 1; // 1 .. 199 .. 0 (start with 1, 0 loads after 199)
  uint1  working_row = 1;
  
  // filtered cross domain (double flip-flop)
  uint1 row_busy_filtered     = 0;
  uint1 vsync_filtered        = 0;

  row_busy_filtered     ::= row_busy; 
  vsync_filtered        ::= vsync;

  // keep sin_valid low by default
  sin_valid := 0;
  
  srw = 0;  // read

  while(1) {

    // wait during vsync
    while (vsync_filtered) {
      row         = 1;
      working_row = 1;
    }    
  
    // wait while the busy row is the working row
    while (working_row == row_busy_filtered) {
      
    }

    // read row from SDRAM to frame buffer
    //    
    // NOTE: here we assume this can be done fast enough such that row_busy
    //       will not change mid-course ... will this be true? 
    //       in any case the HDMI display cannot wait, so apart from error
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
        while (sout_valid == 0) { } // wait for value
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
  output uint22 saddr,
  output uint1  srw,
  output uint32 sdata_in,
  input  uint32 sdata_out,
  input  uint1  sbusy,
  output uint1  sin_valid,
  input  uint1  sout_valid,
  input  uint1  vsync
) {

  // for subroutine bands
  uint9  pix_x = 0;
  uint8  pix_y = 0;  
  uint16 shift = 0;

  subroutine bands:
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
            break;
          }
        } // write occurs during loop cycle      
        pix_x = pix_x + 1;
      }
      pix_y = pix_y + 1;
    }
  return;

  // keep sin_valid low by default
  sin_valid := 0;
  
  srw   = 1;  // write

  while (1) {
    // draw a frame
    call bands;  
    // increment shift
    shift = shift + 1;
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
    output uint1  sdram_clk,
    output uint1  sdram_cle,
    output uint1  sdram_dqm,
    output uint1  sdram_cs,
    output uint1  sdram_we,
    output uint1  sdram_cas,
    output uint1  sdram_ras,
    output uint2  sdram_ba,
    output uint13 sdram_a,
    inout  uint8  sdram_dq,
    // HDMI
    output uint4 hdmi1_tmds,
    output uint4 hdmi1_tmdsb
) <@hdmi_clock,!hdmi_reset> {

uint1 hdmi_clock   = 0;
uint1 sdram_clock  = 0;
uint1 hdmi_reset   = 0;
uint1 sdram_reset  = 0;

// --- clock

clk_wiz clk_gen (
  CLK_IN1  <: clock,
  CLK_OUT1 :> hdmi_clock,
  CLK_OUT2 :> sdram_clock
);

// --- clean reset

reset_conditioner hdmi_rstcond (
  rcclk <: hdmi_clock,
  in  <: reset,
  out :> hdmi_reset
);

reset_conditioner sdram_rstcond (
  rcclk <: sdram_clock,
  in  <: reset,
  out :> sdram_reset
);

// --- HDMI

uint8  hdmi_red   = 0;
uint8  hdmi_green = 0;
uint8  hdmi_blue  = 0;
uint1  hdmi_pclk  = 0;
uint1  hdmi_active = 0;
uint1  hdmi_vsync  = 0;
uint11 hdmi_x = 0;
uint10 hdmi_y = 0;

hdmi_encoder hdmi (
  clk    <: hdmi_clock,
  rst    <: hdmi_reset,
  red    <: hdmi_red,
  green  <: hdmi_green,
  blue   <: hdmi_blue,
  pclk   :> hdmi_pclk,
  tmds   :> hdmi1_tmds,
  tmdsb  :> hdmi1_tmdsb,
  active :> hdmi_active,
  x      :> hdmi_x,
  y      :> hdmi_y
);

// --- SDRAM

uint22 saddr       = 0;
uint1  srw         = 0;
uint32 sdata_in    = 0;
uint32 sdata_out   = 0;
uint1  sbusy       = 0;
uint1  sin_valid   = 0;
uint1  sout_valid  = 0;

sdram memory(
  clk       <: sdram_clock,
  rst       <: sdram_reset,
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

uint22 saddr0      = 0;
uint1  srw0        = 0;
uint32 sd_in0      = 0;
uint32 sd_out0     = 0;
uint1  sbusy0      = 0;
uint1  sin_valid0  = 0;
uint1  sout_valid0 = 0;

uint22 saddr1      = 0;
uint1  srw1        = 0;
uint32 sd_in1      = 0;
uint32 sd_out1     = 0;
uint1  sbusy1      = 0;
uint1  sin_valid1  = 0;
uint1  sout_valid1 = 0;

sdram_switcher sd_switcher<@sdram_clock,!sdram_reset>(
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
    rclk    <: hdmi_pclk,
    raddr   <: pixaddr_r,
    rdata   :> pixdata_r,
    wclk    <: sdram_clock,
    waddr   <: pixaddr_w,
    wdata   <: pixdata_w,
    wenable <: pixwenable
  );

// --- Display

  uint1 display_row_busy = 0;

  frame_display display<@hdmi_pclk,!hdmi_reset>(
    pixaddr   :> pixaddr_r,
    pixdata_r <: pixdata_r,
    display_row_busy :> display_row_busy,
    <:auto:>
  );

// --- Frame buffer row updater

  frame_buffer_row_updater fbrupd<@sdram_clock,!sdram_reset>(
    pixaddr    :> pixaddr_w,
    pixdata_w  :> pixdata_w,
    pixwenable :> pixwenable,
    row_busy   <: display_row_busy,
    vsync      <: hdmi_vsync,
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
    vsync      <: hdmi_vsync,
    saddr      :> saddr1,
    srw        :> srw1,
    sdata_in   :> sd_in1,
    sdata_out  <: sd_out1,
    sbusy      <: sbusy1,
    sin_valid  :> sin_valid1,
    sout_valid <: sout_valid1  
  );
  
  // --- LED
  
  uint22 counter = 0;
  uint8  myled   = 1;
  
  // ---------- unused pins

  spi_miso    := 1bz;
  avr_rx      := 1bz;
  spi_channel := 4bzzzz;

  // ---------- vsync
  hdmi_vsync  := (hdmi_y > 599); // 200*3 - 1
  
  // ---------- bindings

  // on-board LED output (I am alive!)
  led         := myled;
 
  // ---------- let's go

  // start the switcher
  sd_switcher <- ();
  
  // start the frame drawer
  drawer <- ();
  
  // start the frame buffer row updater
  fbrupd <- ();
 
  // start the display driver
  display <- (); 
  
  // alive LED  
  while (1) {
    
    counter = counter + 1;
    if (counter == 0) {
      myled = myled << 1;
      if (myled == 0) {
        myled = 1;
      }
    }
   
  }

}

