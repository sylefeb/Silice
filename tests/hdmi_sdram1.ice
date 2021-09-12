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

// Text buffer
import('dual_text_buffer.v')

// ------------------------- 

algorithm text_display(
  input  uint11 hdmi_x,
  input  uint10 hdmi_y,
  input  uint1  hdmi_active,
  output uint8  hdmi_red,
  output uint8  hdmi_green,
  output uint8  hdmi_blue,
  output uint14 txtaddr,
  input  uint6  txtdata_r
) {

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

  uint8  text_i   = 0;
  uint7  text_j   = 0;
  uint3  letter_i = 0;
  uint4  letter_j = 0;
  uint1  pixel    = 0;
  uint12 addr     = 0;

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

algorithm wait()
{
  uint22 counter = 1;
  
  while (counter != 0) {
    counter = counter + 1;
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
  output uint14 waddr,
  output uint6  wdata,
  output uint1  wenable,
  output uint8  led
  )
{
  uint14 next  = 0;

  // ---------- string
  
  uint8  str[] = "HELLO WORLD FROM FPGA"; 
  uint8  tmp   = 0;
  uint8  step  = 0;
  
  // --------- print string 
  
  uint8  lttr     = 0;
  uint11 col      = 0;
  uint11 str_x    = 64;
  uint10 str_y    = 0;  
 
  int16 rand_x = 113;
  int16 rand_y = 678941;
  
  wait delay;
  
  subroutine print_string(
       readwrites col,
	   reads      str,
	   readwrites lttr,
	   writes sdata_in,
	   writes saddr,
	   writes sin_valid,
	   writes srw,
	   reads  sbusy,
	   reads  str_x,
	   reads  str_y
	   ) {
    col  = 0;
    lttr = str[col];
    srw  = 1;  // write
    while (lttr != 0) {
      if (lttr == 32) {
        lttr = 36;
      } else {
        lttr = lttr - 55;
      }
      // write to sdram
      while (1) {
        if (sbusy == 0) {        // not busy?
          sdata_in  = lttr;
          saddr     = col + str_x + str_y * 160;
          sin_valid = 1; // go ahead!
          break;
        }
      } // write occurs during loop cycle
      // next in string
      col      = col + 1;  
      lttr     = str[col];
    }
    srw = 0;
    return;
  }

  subroutine clear(
       readwrites next,
	   writes sdata_in,
	   writes saddr,
	   writes sin_valid,
	   reads  sbusy,
	   writes srw
	   ) {
    // fill buffer with character table (90x160)
    next = 0;
    srw  = 1;  // write
    while (next < 14400) {
      if (sbusy == 0) {        // not busy?
        sdata_in  = 36;        // data to write  
        saddr     = next;      // address to write to
        sin_valid = 1;         // go ahead!
        next      = next + 1;  // next        
      }
    } // write occurs during loop cycle
    srw = 0;
    return;
  }
  
  subroutine swap(
       readwrites next,
	   writes  saddr,
	   writes  sin_valid,
	   reads   sout_valid,
	   writes  srw,
	   reads   sdata_out,
	   reads   sbusy,
	   writes  wdata,
	   writes  wenable,
	   writes  waddr
	   )  {
    // now read back sdram and write to text buffer
    next = 0;
    srw  = 0;  // read
    while (next < 14400) {
      if (sbusy == 0) {        // not busy?
        saddr     = next;      // address to read from    
        sin_valid = 1;         // go ahead!      
        while (sout_valid == 0) {
          sin_valid = 0; // wait
        }
        // write to text buffer
        wdata   = sdata_out; // data to write
        wenable = 1;
        waddr   = next;     // address to write
     ++: // wait one cycle
        wenable = 0;
        next    = next + 1;  // next
      }
    }
    srw = 0;
    return;
  }
  
  // maintain in_valid to zero, unless otherwise changed
  sin_valid := 0;
  led[0,1]  := sbusy;
  
  while (1) {
  
    () <- clear <- ();
    () <- print_string <- ();
    () <- swap <- ();
    
    rand_x = rand_x * 31421 + 6927;
    rand_y = rand_y * 6927 + 31421;
    
    str_y = rand_y[10,6];
    str_x = rand_x[9,7];
    
    () <- delay <- ();
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

// --- Text buffer

uint14 txtaddr_r = 0;
uint14 txtaddr_w = 0;
uint6  txtdata_r = 0;
uint6  txtdata_w = 0;
uint1  txtwrite  = 0;

dual_text_buffer txtbuf (
  rclk    <: hdmi_pclk,
  raddr   <: txtaddr_r,
  rdata   :> txtdata_r,
  wclk    <: sdram_clock,
  waddr   <: txtaddr_w,
  wdata   <: txtdata_w,
  wenable <: txtwrite
);

// --- Frame drawer

  sdram_draw_frame sdram_draw<@sdram_clock,!sdram_reset>(
    waddr   :> txtaddr_w,
    wdata   :> txtdata_w,
    wenable :> txtwrite,
    <:auto:>
  );

// --- Display

  uint14 disp_txtaddr   = 0;
  uint1  disp_txtwrite  = 0;

  text_display display<@hdmi_pclk,!hdmi_reset>(
    txtaddr   :> txtaddr_r,
    txtdata_r <: txtdata_r,
    <:auto:>
  );

// --- Frame updater

  uint14 draw_txtaddr   = 0;
  uint1  draw_txtwrite  = 0;

// --- LED
  
  uint22 counter = 0;
  // uint8  myled   = 1;
  
  // ---------- unused pins

  spi_miso    := 1bz;
  avr_rx      := 1bz;
  spi_channel := 4bzzzz;

  // ---------- bindings

  // on-board LED output (I am alive!)
  // led := myled;
 
  // ---------- let's go
   
  // start the display driver
  display <- ();
  
  // start the frame drawer
  sdram_draw <- ();
  
  // alive LED  
  while (1) {
    
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

