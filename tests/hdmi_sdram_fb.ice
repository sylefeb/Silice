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

// Frame buffer
import('dual_frame_buffer.v')

// ------------------------- 

algorithm frame_display(
  input  uint11 hdmi_x,
  input  uint10 hdmi_y,
  input  uint1  hdmi_active,
  output uint8  hdmi_red,
  output uint8  hdmi_green,
  output uint8  hdmi_blue,
  output uint16 pixaddr,
  input  uint6  pixdata_r
) {

  uint8 pixel = 0;
  uint9 pix_i = 0;
  uint8 pix_j = 0;
  uint2 sub_j = 0;
  
  // ---------- show time!

  pixaddr = 0;
  
  while (1) {
    
    hdmi_red   = 0;
    hdmi_green = 0;
    hdmi_blue  = 0;

    if (hdmi_active) {

      if (pix_j < 200) {
        pixel      = pixdata_r;
        pixel      = pixel << 4;
        hdmi_red   = pixel;
        hdmi_green = pixel;
        hdmi_blue  = pixel;
      }
      
      // read next
     
      pix_i = hdmi_x >> 2;
      
      if (hdmi_x == 1279) {  
        // end of line
        sub_j = sub_j + 1;
        if (sub_j == 3) {
          sub_j = 0;
          if (pix_j < 199) {
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

    pixaddr = pix_i + pix_j * 320;    

  }
}

// ------------------------- 

algorithm sdram_draw_frame(
  output uint22 saddr,
  output uint1  srw,
  output uint32 sdata_in,
  input  uint32 sdata_out,
  input  uint1  sbusy,
  output uint1  sin_valid,
  input  uint1  sout_valid,
  output uint16 waddr,
  output uint4  wdata,
  output uint1  wenable,
  output uint8  led
  )
{
  uint16 next  = 0;

  // --------- generate bands
  
  uint9 pix_x  = 0;
  uint8 pix_y  = 0;  

  uint24 shift = 0;
  
  subroutine bands:
    srw  = 1;  // write
    pix_y  = 0;  
    while (pix_y < 200) {
      pix_x  = 0;
      while (pix_x < 320) {
        // write to sdram
        while (1) {
          if (sbusy == 0) {        // not busy?
            
            sdata_in  = pix_x + shift;
            
            saddr     = pix_x + pix_y * 320;
            sin_valid = 1; // go ahead!
            break;
          }
        } // write occurs during loop cycle      
        pix_x = pix_x + 1;
      }
      pix_y = pix_y + 1;
    }
    srw = 0;
    return;

  subroutine swap:  
    // now read back sdram and write to text buffer
    next = 0;
    srw  = 0;  // read
    while (next < 64000) {
      if (sbusy == 0) {      // not busy?
        saddr     = next;    // address to read from    
        sin_valid = 1;       // go ahead!      
        while (sout_valid == 0) {
          sin_valid = 0; // wait
        }
        // write to text buffer
        wdata   = sdata_out; // data to write
        wenable = 1;
        waddr   = next;      // address to write
     ++: // wait one cycle
        wenable = 0;
        next    = next + 1;  // next
      }
    }
    srw = 0;
    return;
  
  // maintain in_valid to zero, unless otherwise changed
  sin_valid := 0;
  led[0,1]  := sbusy;
  
  while (1) {
  
    call bands;
    call swap;
    
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

uint22 saddr      = 0;
uint1  srw        = 0;
uint32 sdata_in   = 0;
uint32 sdata_out  = 0;
uint1  sbusy      = 0;
uint1  sin_valid  = 0;
uint1  sout_valid = 0;

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

// --- Frame buffer

uint16 pixaddr_r = 0;
uint16 pixaddr_w = 0;
uint4  pixdata_r = 0;
uint4  pixdata_w = 0;
uint1  pixwrite  = 0;

dual_frame_buffer txtbuf (
  rclk    <: hdmi_pclk,
  raddr   <: pixaddr_r,
  rdata   :> pixdata_r,
  wclk    <: sdram_clock,
  waddr   <: pixaddr_w,
  wdata   <: pixdata_w,
  wenable <: pixwrite
);

// --- Frame drawer

  sdram_draw_frame sdram_draw<@sdram_clock,!sdram_reset>(
    waddr   :> pixaddr_w,
    wdata   :> pixdata_w,
    wenable :> pixwrite,
    <:auto:>
  );

// --- Display

  frame_display display<@hdmi_pclk,!hdmi_reset>(
    pixaddr   :> pixaddr_r,
    pixdata_r <: pixdata_r,
    <:auto:>
  );

// --- LED
  
  uint22 counter = 0;
  // uint8  myled   = 1;
  
  // ---------- unused pins

  spi_miso    := 1bz;
  avr_rx      := 1bz;
  spi_channel := 4bzzzz;

  // ---------- bindings

  // on-board LED output (I am alive!)
  // led <: myled;
 
  // ---------- let's go
   
  // start the display driver
  display <- ();
  
  // start the frame drawer
  sdram_draw <- ();
  
  // alive LED  
  while (1==1) {
    
    // myled = sbusy;
    
  /*
    counter = counter + 1;
    if (counter == 0) {
      myled = myled << 1;
      if (myled == 0) {
        myled = 1;
      }
    }
   */
   
  }

}

