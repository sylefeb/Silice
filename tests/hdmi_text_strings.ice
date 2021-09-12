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
  input  uint11 hdmi_x,
  input  uint10 hdmi_y,
  input  uint1  hdmi_active,
  output uint8  hdmi_red,
  output uint8  hdmi_green,
  output uint8  hdmi_blue
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

  uint1 letters[2432] = {
  //[0] 0
  0,0,1,1,1,1,0,0,
  0,1,0,0,0,1,1,0,
  0,1,0,0,1,0,1,0,
  0,1,0,0,1,0,1,0,
  0,1,0,1,0,0,1,0,
  0,1,0,1,0,0,1,0,
  0,1,1,0,0,0,1,0,
  0,0,1,1,1,1,0,0,
  // 1
  0,0,0,0,1,0,0,0,
  0,0,0,1,1,0,0,0,
  0,0,1,0,1,0,0,0,
  0,0,0,0,1,0,0,0,
  0,0,0,0,1,0,0,0,
  0,0,0,0,1,0,0,0,
  0,0,0,0,1,0,0,0,
  0,0,0,1,1,1,0,0,
  // 2
  0,0,1,1,1,1,0,0,
  0,1,0,0,0,0,1,0,
  0,1,0,0,0,0,1,0,
  0,0,0,0,1,1,1,0,
  0,0,0,1,0,0,0,0,
  0,0,1,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,1,1,1,1,0,0,
  // 3
  0,0,1,1,1,1,0,0,
  0,1,0,0,0,0,1,0,
  0,0,0,0,0,0,1,0,
  0,0,0,1,1,1,0,0,
  0,0,0,0,0,1,0,0,
  0,0,0,0,0,0,1,0,
  0,0,0,0,0,0,1,0,
  0,1,1,1,1,1,0,0,
  // 4
  0,0,0,0,0,1,0,0,
  0,0,0,0,1,1,0,0,
  0,0,0,1,0,1,0,0,
  0,0,1,0,0,1,0,0,
  0,1,1,1,1,1,1,0,
  0,0,0,0,0,1,0,0,
  0,0,0,0,0,1,0,0,
  0,0,0,0,0,1,0,0,
  // 5
  0,1,1,1,1,1,1,0,
  0,1,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,1,1,1,1,0,0,
  0,0,0,0,0,0,1,0,
  0,0,0,0,0,0,1,0,
  0,1,1,1,1,1,0,0,
  // 6
  0,0,0,0,0,1,1,0,
  0,0,0,0,1,0,0,0,
  0,0,0,1,0,0,0,0,
  0,0,1,0,0,0,0,0,
  0,1,1,1,1,1,0,0,
  1,0,0,0,0,0,1,0,
  1,0,0,0,0,0,1,0,
  0,1,1,1,1,1,0,0,
  // 7
  0,1,1,1,1,1,0,0,
  0,0,0,0,0,0,1,0,
  0,0,0,0,0,1,0,0,
  0,0,0,0,0,1,0,0,
  0,0,0,0,0,1,0,0,
  0,0,0,0,1,0,0,0,
  0,0,0,0,1,0,0,0,
  0,0,0,0,1,0,0,0,
  // 8
  0,1,1,1,1,1,0,0,
  1,0,0,0,0,0,1,0,
  1,0,0,0,0,0,1,0,
  1,0,0,0,0,0,1,0,
  0,1,1,1,1,1,0,0,
  1,0,0,0,0,0,1,0,
  1,0,0,0,0,0,1,0,
  0,1,1,1,1,1,0,0,
  // [9] 9
  0,1,1,1,1,1,0,0,
  1,0,0,0,0,0,1,0,
  1,0,0,0,0,0,1,0,
  0,1,1,1,1,1,0,0,
  0,0,0,0,0,1,0,0,
  0,0,0,0,1,0,0,0,
  0,0,0,1,0,0,0,0,
  0,0,1,0,0,0,0,0,
  //[10] a
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
  //[35] z
  0,1,1,1,1,1,1,0,
  0,0,0,0,0,0,1,0,
  0,0,0,0,0,1,0,0,
  0,0,0,0,1,0,0,0,
  0,0,0,1,0,0,0,0,
  0,0,1,0,0,0,0,0,
  0,1,0,0,0,0,0,0,
  0,1,1,1,1,1,1,0,
  //[36] <space>
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,
  //[37] <->
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,
  0,1,1,1,1,1,1,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0
  };

  // ---------- text display

  uint8  text_i   = 0;
  uint7  text_j   = 0;
  uint3  letter_i = 0;
  uint4  letter_j = 0;
  uint1  pixel    = 0;
  uint12 addr     = 0;

  uint16 next     = 0;

  uint8  lttr     = 0;
  uint11 col      = 0;
  uint11 str_x    = 64;
  uint10 str_y    = 39;
  
  int32   numb     = -32h1234;
  uint32  numb_tmp = 0;
  uint8   numb_cnt = 0;
  
  // ---------- string
  
  uint8  str[] = "HELLO WORLD FROM FPGA"; 
  uint8  tmp   = 0;
  uint8  step  = 0;
  
  // --------- print string 
  subroutine print_string:
    col  = 0;
    lttr = str[col];
    while (lttr != 0) {
      if (lttr == 32) {
        lttr = 36;
      } else {
        lttr = lttr - 55;
      }
      txtaddr   = col + str_x + str_y * 160;    
      txtdata_w = lttr[0,6];
      col       = col + 1;  
      lttr      = str[col];
    }
  return;

  // --------- print number 
  subroutine print_number:
    if (numb < 0) {
      numb_cnt = 1;
      numb_tmp = -numb;
    } else {
      numb_cnt = 0;
      numb_tmp = numb;
    }
    while (numb_tmp > 0) {
      numb_cnt = numb_cnt + 1;
      numb_tmp = numb_tmp >> 4;
    }
    col = 0;
    if (numb < 0) {
      numb_tmp = -numb;
      // output sign
      txtaddr   = str_x + str_y * 160;    
      txtdata_w = 37;
    } else {
      numb_tmp = numb;
    }
    while (numb_tmp > 0) {
      lttr      = (numb_tmp & 15);
      txtaddr   = numb_cnt - 1 - col + str_x + str_y * 160;    
      txtdata_w = lttr[0,6];
      col       = col + 1;  
      numb_tmp  = numb_tmp >> 4;
    }
  return;

  // fill buffer with spaces
  txtwrite  = 1;
  next      = 0;
  txtdata_w = 36; // data to write
  while (next < 12800) {
    txtaddr = next;     // address to write
    next    = next + 1; // next
  }

  // print number
  call print_number;
  str_y = str_y + 2;
  
  // print string
  call print_string;
  str_y = str_y + 2;

  // ---------- sorting network (because we can)

    step = 0;
    while (step < 21) {
      // even
$$  for i=0,18,2 do
      if (str[$i$] > str[$i+1$]) {
        tmp = str[$i$];
        str[$i$] = str[$i+1$];
        str[$i+1$] = tmp;
      }
$$  end
      // odd
$$  for i=1,19,2 do
      if (str[$i$] > str[$i+1$]) {
        tmp = str[$i$];
        str[$i$] = str[$i+1$];
        str[$i+1$] = tmp;
      }
$$  end
    step = step + 1;
  }

  // ---------- 

  // print string again, below
  call print_string;
  str_y = str_y + 2;
  
  // and again, to test
  call print_string;
  str_y = str_y + 2;
  
  // ---------- show time!

  // stop writing to buffer
  txtwrite = 0;
  txtaddr  = 0;   

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
    // HDMI
    output uint4 hdmi1_tmds,
    output uint4 hdmi1_tmdsb
) <@hdmi_clock,!stable_reset> {

uint1 hdmi_clock = 0;
uint1 stable_reset = 0;

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
uint8  hdmi_red   = 0;
uint8  hdmi_green = 0;
uint8  hdmi_blue  = 0;
uint1  hdmi_pclk  = 0;
uint1  hdmi_active = 0;
uint11 hdmi_x = 0;
uint10 hdmi_y = 0;

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

  uint21 counter = 0;
  uint8  myled   = 1;
  
  display.hdmi_x := hdmi_x;
  display.hdmi_y := hdmi_y;
  display.hdmi_active := hdmi_active;

  hdmi_red   := display.hdmi_red;
  hdmi_green := display.hdmi_green;
  hdmi_blue  := display.hdmi_blue;

  // ---------- unused pins

  spi_miso := 1bz;
  avr_rx := 1bz;
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

