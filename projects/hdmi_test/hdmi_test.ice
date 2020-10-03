// -------------------------

// HDMI driver
$include('../common/hdmi.ice')

// ----------------------------------------------------

$$if not ULX3S then
$$error('this project has been only tested for the ULX3S, other boards will require some changes')
$$end

algorithm main(
  // SDRAM
  output uint1  sdram_cle,
  output uint1  sdram_dqm,
  output uint1  sdram_cs,
  output uint1  sdram_we,
  output uint1  sdram_cas,
  output uint1  sdram_ras,
  output uint2  sdram_ba,
  output uint13 sdram_a,
  output uint1  sdram_clk,
  inout  uint8  sdram_dq,
  // sdcard
  output  uint1 sd_clk,
  output  uint1 sd_mosi,
  output  uint1 sd_csn,
  input   uint1 sd_miso,
  // led
  output uint8  leds,
  // buttons
  input  uint7  btn,
  // video
  output uint3  gpdi_dp,
  output uint3  gpdi_dn
)
{

  uint10 x      = 0;
  uint10 y      = 0;
  uint1  active = 0;
  uint1  vblank = 0;
  uint8  r      = 0;
  uint8  g      = 0;
  uint8  b      = 0;
  
  hdmi video(
    x       :> x,
    y       :> y,
    active  :> active,
    vblank  :> vblank,
    gpdi_dp :> gpdi_dp,
    gpdi_dn :> gpdi_dn,
    red     <: r,
    green   <: g,
    blue    <: b
  );
  
  leds = 0;
  while (1) { 
  
    if (active) {
      r = x;
      g = y;
      b = (x+y);
    }
    
  }
  
}

// ----------------------------------------------------
