# Racing the beam in VGA, framework and demos!

This folder contains a small framework to create VGA demos, shader-style.
All these demos are racing the beam, e.g. the picture is produced while the VGA
signal is generated, without any framebuffer.

The main file is [vga_demo_main.si](vga_demo_main.si). Each demo includes it and then defines a
`frame_display` module that computes a color for each pixel, as the VGA signal
is being generated. Yes, there is no framebuffer here!
(if you are familiar with GPU pixel shaders, this is a very similar programming
style for the effects, except that we
are [racing the beam](https://en.wikipedia.org/wiki/Racing_the_Beam) here).

Demos typically run on the IceStick (with [VGA DAC page](../DIYVGA.md)),
IceBreaker and ECPIX5 (with VGA PMOD), de10-nano (with I/O board VGA).
Note that the custom [VGA DAC page](../DIYVGA.md) can be connected to all
boards with the proper pinout (see link).

All demos can be run in simulation (opens a graphical window) with e.g.
`make verilator -f Makefile.flyover3d` for the flyover demo.

To build for specific hardware use `make <target>`, for instance `make icebreaker`.
Similarly use `-f` to select a specific demo.

Available demos:
- [Roto texture](vga_rototexture.si), use `-f Makefile.rototexture`
- [Flying over a plane](vga_flyover3d.si), use `-f Makefile.flyover3d`
- [Copper bars](vga_copperbars.si), use `-f Makefile.copperbars`
- [3D Menger sponge pipeline](vga_msponge.si), use `-f Makefile.msponge`
- [rsqrt tunnel](vga_circles.si), use `-f Makefile.circles`
- [Monte Carlo geometry](vga_mc.si), use `-f Makefile.mc`

<p align="center">
  <img width="300" src="vga_demo_copperbars.png">
  <img width="300" src="vga_demo_flyover3d.png">
  <img width="300" src="vga_demo_rototex.png">
</p>

## Credits
- Ring oscillator for the ECP5 from https://github.com/dpiegdon/verilog-buildingblocks, by David R. Piegdon (GPLv3)
