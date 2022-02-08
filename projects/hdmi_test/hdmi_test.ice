// MIT license, see LICENSE_MIT in Silice repo root
// @sylefeb 2019
// https://github.com/sylefeb/Silice

// HDMI driver
$include('../common/hdmi.ice')

$$if MOJO then
import('mojo_clk_50_25_125_125n.v')
$$end

// ----------------------------------------------------

$$if not ULX3S and not MOJO then
$$ -- error('this project has been only tested for the ULX3S, other boards will require some changes')
$$end

algorithm main(
  // led
  output uint8  leds,
  // video
  output! uint4 gpdi_dp,
$$if ICARUS then
  output! uint4 gpdi_dn(0),
$$end
) {

  uint10 x      = 0; // (output) the active pixel x coordinate
  uint10 y      = 0; // (output) the active pixel y coordinate
  uint1  active = 0; // (output) whether the active screen area is being drawn
  uint1  vblank = 0; // (output) whether vblank is active (interval between frames)
  uint8  r      = 0; // (input)  the red value of the active pixel
  uint8  g      = 0; // (input) the green value of the active pixel
  uint8  b      = 0; // (input) the blue value of the active pixel

  hdmi video(
    x       :> x,
    y       :> y,
    active  :> active,
    vblank  :> vblank,
    gpdi_dp :> gpdi_dp,
    red     <: r,
    green   <: g,
    blue    <: b
  );

$$if SIMULATION then
  uint10 count = 0;
$$end

  leds = 0;
$$if SIMULATION then
  while (count < 256) {
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
