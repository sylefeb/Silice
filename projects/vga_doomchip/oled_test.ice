// SL 2020-05

import('../../common/de10nano_clk_100_25.v')
import('../../common/reset_conditioner.v')

$include('oled.ice')

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
  output! uint1  oled_din,
  output! uint1  oled_clk,
  output! uint1  oled_cs,
  output! uint1  oled_dc,
  output! uint1  oled_rst,  
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

  oledio io;
  oled   display(
    oled_din :> oled_din,
    oled_clk :> oled_clk,
    oled_cs  :> oled_cs,
    oled_dc  :> oled_dc,
    oled_rst :> oled_rst,
    io      <:> io
  );

  led      := 0;
  
  while (1) {
    
    while (io.ready == 0) { }

  }
}

// ------------------------- 
