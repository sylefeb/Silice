# HDMI test

This project is a simple test of the [Silice HDMI implementation](../common/hdmi.ice)

It outputs a 640x480 HDMI signal, with a pixel clock of 25 MHz and hence a signal clock of 250 MHz (10 bits per pixel for the HDMI protocol).
This example assumes the base clock is 25 MHz, which is the case for instance on the ULX3S.

**Note:** This project was primarily designed for the ULX3S board ; it is possible to adapt it for other boards but will require to replace
ECP5/Lattice specific primitives in [differential_pair.v](../common/differential_pair.v).

## Example code walkthrough

The main algorithm first declares a number of variables that allow us to interact with the HDMI controller:

```c
  uint10 x      = 0; // (output) the active pixel x coordinate
  uint10 y      = 0; // (output) the active pixel y coordinate
  uint1  active = 0; // (output) whether the active screen area is being drawn
  uint1  vblank = 0; // (output) whether vblank is active (interval between frames)
  uint8  r      = 0; // (input)  the red value of the active pixel
  uint8  g      = 0; // (input) the green value of the active pixel
  uint8  b      = 0; // (input) the blue value of the active pixel
```

It then instantiates the HDMI controller and bind these variables to it. Note the syntax `:>` indicating an output (e.g. x,y) and `<:` indicating an input (r,g,b).
From this point on, the variables are bound to the HDMI controller and directly reflect its internal state. 

```c
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
```

The controller forms the HDMI signal, which is output on the pins `gpdi_dp` and `gpdi_dn`. The HDMI protocol uses a 4 bits signal (red, green, blue, clock), but this signal is sent to the screen through two sets of pins (for a total of eight pins): positive and negative. Each positive and negative bits forms a pair, called a *differential* pair. This is done to strongly improve the signal quality and integrity. Thus, `gpdi_dp` encodes the signals on four bits and `gpdi_dn` are their negated counterpart (we have `gpdi_dn = ~gpdi_dp`).

Now we are ready to draw on screen! We enter an infinite loop, that computes r,g,b from x,y. If you have
done GPU shaders in the past, this is very similar to a pixel shader in concept.

The example draws simple red-green ramp along x/y as well as blue diagonals, with the following code:

```c
  leds = 0;
  while (1) { 
    if (active) {
      r = x;
      g = y;
      b = (x+y);
    }    
  }
```  

## HDMI code walkthrough

**TODO**
