# VGA demo framework, with examples

This folder contains a small framework to create VGA demos, shader-style.

The main file is *vga_demo_main.ice*. Each demo includes it and then defines a
*frame_display* module that computes a color for each pixel, as the VGA signal
is being generated. Yes, there is no framebuffer here!

To run it on real hardware, see the [VGA DAC page](../DIYVGA.md).

All these demos run on an IceStick.
