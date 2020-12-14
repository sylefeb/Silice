# HDMI test

This project is a test example of the [Silice HDMI example implementation](../common/hdmi.ice)

It outputs a 640x480 HDMI signal, with a pixel clock of 25 MHz and hence a signal clock of 250 MHz (10 bits per pixel for the HDMI protocol).

**Note:** This project was tested on the ULX3S board.

## Example code walkthrough

The main algorithm first declares a number of variables that will allow 
us to interact with the HDMI controller:

```c
  uint10 x      = 0; // (output) the active pixel x coordinate
  uint10 y      = 0; // (output) the active pixel y coordinate
  uint1  active = 0; // (output) whether the active screen area is being drawn
  uint1  vblank = 0; // (output) whether vblank is active (interval between frames)
  uint8  r      = 0; // (input)  the red value of the active pixel
  uint8  g      = 0; // (input) the green value of the active pixel
  uint8  b      = 0; // (input) the blue value of the active pixel
```

We then instantiate the HDMI controller and bind these variables to it. Note the syntax `:>` indicating an output (x,y,...) and `<:` indicating an input (r,g,b).

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

Now we are ready to draw on screen! We enter an infinite loop, that computes r,g,b from x,y. If you have
done GPU shaders in the past, this is very similar!

The example draws simple red-green ramps along x/y as well as blue diagonals, with the following code:

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
