// -------------------------

// HDMI driver
$include('../common/hdmi.ice')

// ----------------------------------------------------

$$if not ULX3S then
$$ -- error('this project has been only tested for the ULX3S, other boards will require some changes')
$$end

algorithm main(
  // led
  output uint8  leds,
  // video
  output uint4  gpdi_dp,
  output uint4  gpdi_dn
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
  
    if (active) {
      r = x;
      g = y;
      b = (x+y);
    }
    
  }
  
}

// ----------------------------------------------------
