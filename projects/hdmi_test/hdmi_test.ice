// -------------------------

// HDMI driver
$include('../common/hdmi.ice')

$$if MOJO then
import('mojo_clk_50_25_125_125n.v')
$$end

$include('clean_reset.ice')

// ----------------------------------------------------

$$if not ULX3S and not MOJO then
$$ -- error('this project has been only tested for the ULX3S, other boards will require some changes')
$$end

algorithm main(
  // led
  output uint8  leds,
  // video
  output uint4  gpdi_dp,
//  output uint4  gpdi_dn,
) <@pixel_clk,!rst> {

uint1  pixel_clk       = uninitialized;
uint1  half_hdmi_clk   = uninitialized;
uint1  half_hdmi_clk_n = uninitialized;
mojo_clk_50_25_125_125n mclk(
  CLK_IN1  <: clock,
  CLK_OUT2 :> pixel_clk,
  CLK_OUT3 :> half_hdmi_clk,
  CLK_OUT4 :> half_hdmi_clk_n,
  RESET    <: reset,
);
uint1  rst  = uninitialized;
clean_reset cr<@pixel_clk,!reset>(
  out :> rst
);

  uint10 x      = 0; // (output) the active pixel x coordinate
  uint10 y      = 0; // (output) the active pixel y coordinate
  uint1  active = 0; // (output) whether the active screen area is being drawn
  uint1  vblank = 0; // (output) whether vblank is active (interval between frames)
  uint8  r      = 0; // (input)  the red value of the active pixel
  uint8  g      = 0; // (input) the green value of the active pixel
  uint8  b      = 0; // (input) the blue value of the active pixel
  
  hdmi video<@pixel_clk>(
    x       :> x,
    y       :> y,
    active  :> active,
    vblank  :> vblank,
    gpdi_dp :> gpdi_dp,
//    gpdi_dn :> gpdi_dn,
    red     <: r,
    green   <: g,
    blue    <: b,
    half_hdmi_clk   <: half_hdmi_clk,
    half_hdmi_clk_n <: half_hdmi_clk_n
  );
  
$$if SIMULATION then
  uint4 count = 0;
$$end

  leds = 0;
$$if SIMULATION then
  while (count < 8) { 
    count = count + 1;
$$else  
  while (1) { 
$$end
  
    leds = x;

    if (active) {
      r = x;
      g = y;
      b = (x+y);
    }
    
  }
  
}

// ----------------------------------------------------
