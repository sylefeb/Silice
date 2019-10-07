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

import('clk_wiz_v3_6.v')
import('hdmi_encoder.v')

// ------------------------- 

algorithm main(
    output int8 led,
    output int1 spi_miso,
    input int1 spi_ss,
    input int1 spi_mosi,
    input int1 spi_sck,
    output int4 spi_channel,
    input int1 avr_tx,
    output int1 avr_rx,
    input int1 avr_rx_busy,
    // SDRAM
    output int1 sdram_clk,
    output int1 sdram_cle,
    output int1 sdram_dqm,
    output int1 sdram_cs,
    output int1 sdram_we,
    output int1 sdram_cas,
    output int1 sdram_ras,
    output int2 sdram_ba,
    output int13 sdram_a,
    inout  int8 sdram_dq,
    // HDMI
    output int4 hdmi1_tmds,
    output int4 hdmi1_tmdsb
) <@hdmi_clock,!stable_reset> {

// generate clock for HDMI
clk_wiz_v3_6 clk_gen (
  CLK_IN1  <: clock,
  CLK_OUT1 :> hdmi_clock
);

// reset conditionner
reset_conditioner rstcond (
  rcclk <: hdmi_clock,
  in  <: reset,
  out :> stable_reset
);

// bind to HDMI encoder
int8  hdmi_red   = 0;
int8  hdmi_green = 0;
int8  hdmi_blue  = 0;
int1  hdmi_pclk  = 0;
int1  hdmi_active = 0;
int11 hdmi_x = 0;
int10 hdmi_y = 0;

hdmi_encoder hdmi (
  clk    <: hdmi_clock,
  rst    <: stable_reset,
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

// ---------- variables

int10 frame  = 0;
int10 dotpos = 0;
int2  speed  = 0;
int2  inv_speed = 0;
int16 rand_x_init = 1;
int16 rand_x = 0;
int16 rand_y = 0;

// ---------- always assignements

// unused pins
spi_miso    := 1bz;
avr_rx      := 1bz;
spi_channel := 4bzzzz;

// on-board LED output (I am alive!)
led := frame;

// ---------- show time!
loop:

  if (hdmi_y == 0) {
    rand_y = 1;
    rand_x_init = 1;
  } else {   
    rand_y   = rand_y * 31421 + 6927;
  }

  if (hdmi_x == 0) {
    rand_x = rand_x_init;
    if (rand_y & 1 != 0) {
      rand_x_init = rand_x_init * 31421 + 6927;
    }
    if ((rand_y>>1) & 1 != 0) {
      rand_x_init = rand_x_init * 31421 + 6927;
    }
  } else {   
    rand_x = rand_x * 31421 + 6927;
  }
  
  
  speed  = rand_x[12,2];
  dotpos = (frame >> speed) + rand_x;
   
  if (hdmi_y == dotpos) {
    inv_speed  = 3 - speed;
    hdmi_red   = 8d127 + (8d16 << inv_speed);
    hdmi_green = 8d127 + (8d16 << inv_speed);
    hdmi_blue  = 8d127 + (8d16 << inv_speed);
  } else {
    hdmi_red   = 0;
    hdmi_green = 0;
    hdmi_blue  = 0;    
  }
  
  if (hdmi_x == 1279 && hdmi_y == 719 && hdmi_active) {
    // end of frame
    frame = frame + 1;
  }
  
  goto loop;

}

