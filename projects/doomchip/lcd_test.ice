// SL 2020-05
// MIT license, see LICENSE_MIT in Silice repo root

import('../common/de10nano_clk_100_25.v')
import('../common/reset_conditioner.v')

$include('lcd.ice')

// ------------------------- 

algorithm main(
  output! uint1  sdram_cle,
  output! uint1  sdram_dqm,
  output! uint1  sdram_cs,
  output! uint1  sdram_we,
  output! uint1  sdram_cas,
  output! uint1  sdram_ras,
  output! uint2  sdram_ba,
  output! uint13 sdram_a,
  output! uint1  sdram_clk,
  inout   uint8  sdram_dq,
  output! uint8  led,
  output! uint4  kpadC,
  input   uint4  kpadR,
  output! uint1  lcd_rs,
  output! uint1  lcd_rw,
  output! uint1  lcd_e,
  output! uint8  lcd_d,
  output! uint$color_depth$ video_r,
  output! uint$color_depth$ video_g,
  output! uint$color_depth$ video_b,
  output! uint1 video_hs,
  output! uint1 video_vs
) <@sdram_clock,!sdram_reset> {

  uint1 video_reset = 0;
  uint1 sdram_reset = 0;

  // --- clock
  uint1 video_clock  = 0;
  uint1 sdram_clock  = 0;
  uint1 pll_lock     = 0;
  uint1 not_pll_lock = 0;
  de10nano_clk_100_25 clk_gen(
    refclk    <: clock,
    rst       <: not_pll_lock,
    outclk_0  :> sdram_clock,
    outclk_1  :> video_clock,
    locked    :> pll_lock
  );
  // --- video clean reset
  reset_conditioner video_rstcond (
    rcclk <: video_clock,
    in    <: reset,
    out   :> video_reset
  );  
  // --- SDRAM clean reset
  reset_conditioner sdram_rstcond (
    rcclk <: sdram_clock,
    in  <: reset,
    out :> sdram_reset
  );

  uint8  msg1[17] = "DooM-chip   v0.1";
  uint8  msg2[17] = "E1M1            ";
  uint8  msg3[17] = "interactive mode";
  uint26 counter  = 1;
  
  subroutine printMessage(
    readwrites  io,
    input uint8 msg[17]
  ) {
    uint8 i = 0;  
    while (msg[i] != 0) {
      while (io.ready == 0) { }
      io.data   = msg[i];
      io.print  = 1;
      i         = i + 1;
    }  
  }
  
  lcdio io;
  lcd   display(
    lcd_rs :> lcd_rs,
    lcd_rw :> lcd_rw,
    lcd_e  :> lcd_e,
    lcd_d  :> lcd_d,
    io    <:> io
  );

  led      := 0;
  
  io.print  := 0;
  io.setrow := 0;

  () <- printMessage <- (msg1);

  while (1) {
    
    while (io.ready == 0) { }
    io.data   = 1;
    io.setrow = 1;
    
    () <- printMessage <- (msg2);

    counter = 1;
    while (counter != 0) {
      counter = counter + 1;
    }
    
    while (io.ready == 0) { }
    io.data   = 1;
    io.setrow = 1;
    
    () <- printMessage <- (msg3);

    counter = 1;
    while (counter != 0) {
      counter = counter + 1;
    }

  }
}

// ------------------------- 
