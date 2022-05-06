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

// Text buffer
import('text_buffer.v')

// ------------------------- 

algorithm text_display(
  input  int11 hdmi_x,
  input  int10 hdmi_y,
  input  int1  hdmi_active,
  output int8  hdmi_red,
  output int8  hdmi_green,
  output int8  hdmi_blue
) <autorun> {

// Text buffer

int14 txtaddr   = 0;
int5  txtdata_r = 0;
int5  txtdata_w = 0;
int1  txtwrite  = 0;

text_buffer txtbuf (
  clk     <: clock,
  addr    <: txtaddr,
  wdata   <: txtdata_w,
  rdata   :> txtdata_r,
  wenable <: txtwrite
);

// ---------- font

  int1  letters[1728] = {
  // a
  0,0,0,1,1,0,0,0,
  0,0,1,0,0,1,0,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,1,1,1,1,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  // b
  0,1,1,1,1,0,0,0,
  0,1,0,0,0,1,0,0,
  0,1,0,0,0,1,0,0,
  0,1,0,0,1,0,0,0,
  0,1,1,1,1,1,0,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,1,1,1,1,0,0,
  // c
  0,0,0,1,1,1,0,0,
  0,0,1,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,0,1,0,0,0,0,0,
  0,0,0,1,1,1,1,0,
  // d
  0,1,1,1,1,0,0,0,
  0,1,0,0,0,1,0,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,1,1,0,
  0,1,1,1,1,0,0,0,
  // e
  0,1,1,1,1,1,0,0,
  0,1,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,1,1,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,1,1,1,1,1,0,
  // f
  0,1,1,1,1,1,1,0,
  0,1,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,1,1,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  // g
  0,0,0,1,1,1,0,0,
  0,0,1,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,0,0,1,1,1,0,
  0,1,0,0,0,0,1,0,
  0,0,1,0,0,0,1,0,
  0,0,0,1,1,1,1,0,
  // h
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,1,1,1,1,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  // i
  0,0,0,1,1,0,0,0,
  0,0,0,1,1,0,0,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,1,0,0,0,
  0,0,0,0,1,0,0,0,
  0,0,0,0,1,0,0,0,
  0,0,0,0,1,0,0,0,
  0,0,0,0,1,0,0,0,
  // j
  0,0,0,0,1,1,0,0,
  0,0,0,0,1,1,0,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,1,0,0,
  0,0,0,0,0,1,0,0,
  0,0,0,0,0,1,0,0,
  0,1,0,0,0,1,0,0,
  0,0,1,1,1,0,0,0,
  // k
  0,1,0,0,1,0,0,0,
  0,1,0,0,1,0,0,0,
  0,1,0,0,1,0,0,0,
  0,1,0,1,0,0,0,0,
  0,1,1,1,0,0,0,0,
  0,1,0,0,1,0,0,0,
  0,1,0,0,0,1,0,0,
  0,1,0,0,0,1,0,0,
  // l
  0,1,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,0,1,1,1,1,0,0,
  // m
  0,0,0,0,0,0,0,0,
  0,1,1,0,0,1,1,0,
  1,0,0,1,1,0,0,1,
  1,0,0,0,0,0,0,1,
  1,0,0,0,0,0,0,1,
  1,0,0,0,0,0,0,1,
  1,0,0,0,0,0,0,1,
  1,0,0,0,0,0,0,1,
  // n
  0,1,0,0,0,0,1,0,
  0,1,1,0,0,0,1,0,
  0,1,0,1,0,0,1,0,
  0,1,0,0,1,0,1,0,
  0,1,0,0,0,1,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  // o
  0,0,1,1,1,1,0,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,0,1,1,1,1,0,0,
  // p
  0,0,1,1,1,1,0,0,
  0,0,1,0,0,0,1,0,
  0,0,1,0,0,0,1,0,
  0,0,1,0,0,0,1,0,
  0,0,1,1,1,1,1,0,
  0,0,1,0,0,0,0,0,
  0,0,1,0,0,0,0,0,
  0,0,1,0,0,0,0,0,
  // q
  0,0,1,1,1,1,0,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,1,0,0,1,0,
  0,0,1,0,0,0,1,0,
  0,1,0,1,1,1,0,0,
  // r
  0,1,1,1,1,1,0,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,1,1,1,1,0,0,
  0,1,0,0,0,1,0,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,0,1,
  // s
  0,0,1,1,1,1,0,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,0,1,1,1,1,0,0,
  0,0,0,0,0,0,1,0,
  0,0,0,0,0,0,1,0,
  0,1,1,1,1,1,0,0,
  // t
  1,1,1,1,1,1,1,0,
  0,0,0,1,0,0,0,0,
  0,0,0,1,0,0,0,0,
  0,0,0,1,0,0,0,0,
  0,0,0,1,0,0,0,0,
  0,0,0,1,0,0,0,0,
  0,0,0,1,0,0,0,0,
  0,0,0,1,0,0,0,0,
  // u
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,0,1,1,1,1,0,0,
  // v
  1,0,0,0,0,0,0,1,
  1,0,0,0,0,0,0,1,
  1,0,0,0,0,0,0,1,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,0,1,0,0,1,0,0,
  0,0,1,0,0,1,0,0,
  0,0,0,1,1,0,0,0,
  // w
  1,0,0,0,0,0,0,1,
  1,0,0,0,0,0,0,1,
  1,0,0,0,0,0,0,1,
  1,0,0,0,0,0,0,1,
  0,1,0,0,0,0,1,0,
  0,1,0,1,1,0,1,0,
  0,1,0,1,1,0,1,0,
  0,0,1,0,0,1,0,0,
  // x
  0,1,0,0,0,1,0,0,
  0,1,0,0,0,1,0,0,
  0,1,0,0,0,1,0,0,
  0,0,1,0,1,0,0,0,
  0,0,0,1,0,0,0,0,
  0,0,1,0,1,0,0,0,
  0,1,0,0,0,1,0,0,
  0,1,0,0,0,1,0,0,
  // y
  1,0,0,0,0,1,0,0,
  1,0,0,0,0,1,0,0,
  0,1,0,0,1,0,0,0,
  0,0,1,0,1,0,0,0,
  0,0,0,1,0,0,0,0,
  0,0,0,1,0,0,0,0,
  0,0,1,0,0,0,0,0,
  0,0,1,0,0,0,0,0,
  // z
  0,1,1,1,1,1,1,0,
  0,0,0,0,0,0,1,0,
  0,0,0,0,0,1,0,0,
  0,0,0,0,1,0,0,0,
  0,0,0,1,0,0,0,0,
  0,0,1,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,1,1,1,1,1,0,
  // <space>
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0
  };
  
  // ---------- text display

  int8  text_i   = 0;
  int7  text_j   = 0;
  int3  letter_i = 0;
  int4  letter_j = 0;
  int1  pixel    = 0;
  int11 addr     = 0;

  int16 next     = 0;
  int16 rand     = 1;
  int5  lttr     = 0;
  
  // ---------- init text (random)

    txtwrite = 1;
  text_init:
    // write to buffer
    txtaddr   = next;
    lttr      = rand[11,5] & 31;
    if (lttr > 26) {
      lttr = lttr - 27;
    }
    txtdata_w = lttr;
  ++: // wait 1 clock for write to complete
    rand      = rand * 31421 + 6927;  
    next      = next + 1;
    if (next == 12800) {
      goto text_init_done;
    } else {
      goto text_init;
    }
  text_init_done:
    txtwrite = 0;
    txtaddr  = 0;
    
  // ---------- show time!

  loop:
    
    hdmi_red   = 0;
    hdmi_green = 0;
    hdmi_blue  = 0;

    if (letter_j < 8) {
      letter_i = hdmi_x & 7;
      addr     = letter_i + (letter_j << 3) + (txtdata_r << 6);
      pixel    = letters[ addr ];
      if (hdmi_active && pixel == 1) {
        hdmi_red   = 255;
        hdmi_green = 255;
        hdmi_blue  = 255;
      }
    }

    if (hdmi_active && (hdmi_x & 7) == 7) {   // end of letter
      text_i = text_i + 1;
      if (hdmi_x == 1279) {  // end of line
        // back to first column
        text_i   = 0;
        // next letter line
        if (letter_j < 8) {
          letter_j = letter_j + 1;
        } else {
          // next row
          letter_j = 0;
          text_j   = text_j + 1;
        }
        if (hdmi_y == 719) {
          // end of frame
          text_i   = 0;
          text_j   = 0;
          letter_j = 0;      
        }
      }
    } 

    txtaddr  = text_i + text_j * 160;

  goto loop;
}

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

int1 hdmi_clock = 0;
int1 stable_reset = 0;

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

  text_display display<@hdmi_pclk>;

  int21 counter = 0;
  int8  myled   = 1;
  
  display.hdmi_x      := hdmi_x;
  display.hdmi_y      := hdmi_y;
  display.hdmi_active := hdmi_active;

  hdmi_red   := display.hdmi_red;
  hdmi_green := display.hdmi_green;
  hdmi_blue  := display.hdmi_blue;

  // ---------- unused pins

  spi_miso    := 1bz;
  avr_rx      := 1bz;
  spi_channel := 4bzzzz;

  // ---------- bindings

  // on-board LED output (I am alive!)
  led := myled;
  
loop: 

  counter = counter + 1;
  if (counter == 0) {
    myled = myled << 1;
    if (myled == 0) {
      myled = 1;
    }
  }

goto loop;

}

