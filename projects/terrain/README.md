# Tiny terrain renderer on ice40 UP5K

This project is a recreation in FPGA hardware of the classic Voxel Space terrain renderer featured in games such as [Comanche](https://en.wikipedia.org/wiki/Comanche_(video_game_series)). 

It was developed and tested on an IceBreaker board with VGA PMOD.

### How to test

A RISC-V environment is needed, see [Getting Started](../../GetStarted.md).

- **With an Icebreaker**: plug your board, then from a command line in this directory `./build.sh`
- **In simulation**: from a command line in this directory `./simul.sh` ; this requires the [Verilator framework](../../GetStarted.md).

### Design files

- [`main.ice`](main.ice) is the main framework
- [`terrain_renderer.ice`](terrain_renderer.ice) is the hardware renderer
- [`firmware.c`](firmware.c) is the RISC-V firmware code

## Revisiting the Voxel Space algorithm in hardware

The main principle of the terrain renderer is similar to the Voxel Space
renderer. This [github repo by s-macke](https://github.com/s-macke/VoxelSpace) gives an excellent overview of the algorithm. I give below some explanations to make this README self-contained but please checkout [s-macke](https://github.com/s-macke/VoxelSpace)'s page for more details and illustrations.

### First, some memory considerations

A key challenge in fitting this on an UP5K is the limited memory. A terrain renderer typically uses a large amount of memory to store the terrain data: elevation and color map. 

Our UP5K FPGA features two types of specialized memories: BRAM (Block RAM) and SPRAM (Single Port RAM). These are very fast, returning a value in a single clock cycle, but they are also in limited supply: we have 128 kilobytes in four SPRAMs (each 32 kilobytes), plus 120 kilobits (*bits* not *bytes*) of dual-port BRAM. That's not much. In contrast, a single map of the original Comanche game is 2 megabytes (color + height), and a 320x200 framebuffer is already 64 kilobytes (320 x 200 x 8 bits for a 256 colors palette).

Of course we can always downsample the maps, and we will do just that, using maps of 128x128 pixels. However the loss in resolution is extreme, and the results on screen would be far from pleasing using the original algorithm. So we cannot stop there, we need some tricks. In particular, we will resort on both interpolation and dithering. More on that later.

Many rendering algorithms require two framebuffers: one is displayed while the next frame is drawn in a second buffer,  hidden from view. This is called *[double buffering](https://en.wikipedia.org/wiki/Multiple_buffering)*. It is important when, for instance, the previous view has to be cleared before drawing afresh. However, our terrain renderer draws the view from front to back, allowing to use a single framebuffer. As the next frame is quite similar to the previous one (the viewpoint changes progressively), the difference will not produce perceivable flickering as the frame is drawn in front of our eyes, apart from a potential screen tearing effect.

Alright, so we've settled on a 8bits color palette, maps of 128x128 and screen resolution of 320x200. Our memory budget looks like that:
- 128x128 8bits terrain height (16KB)
- 128x128 8bits terrain color  (16KB)
- one 320x200 8bits framebuffer (64KB)
So that's a grand total of 96KB, leaving some free SPRAM for future expansions.

This also fits nicely in four SPRAMs:
- SPRAM A, 32KB, framebuffer, 4bits of each pixel (least significant)
- SPRAM B, 32KB, framebuffer, 4bits of each pixel (most significant)
- SPRAM C, 32KB, interleaved height + color data (16bits per pixel)
- SPRAM D, 32KB, free!

### Overall algorithm

The design for the renderer is in [`terrain_renderer.ice`](terrain_renderer.ice).

This demo implements the simplest form of the algorithm, which renderers a viewpoint
aligned with the y-axis. This means we are looking along y, and that the screen x-axis is aligned with x-spans of the terrain data.

Rotations are thus not yet possible (but of course a natural extension!).

The view is renderer front to back in a sequence of *z-steps*. Each z-step traverses the data along the x-axis as shown below: each white line (one z-step) is sampled 320 times (the screen width) to get the terrain height on a given screen column while the x-axis is traversed.

<p align="center">
  <img width="400" src="figure_zsteps.png">
</p>

Given the height for the screen column at x, we compute the y position on screen by perspective projection (division by the distance from view). We then draw a vertical segment, from the position of the last z-step to the new one.
The animation below reveals the z-steps, drawn one after the other from front to back.

<p align="center">
  <img width="400" src="figure_zsteps.gif">
</p>

Between each z-step, two arrays `y_last` and `c_last` record the color and screen height reached by the previous z-step. The height is used to restart from this height when drawing the next z-step. Note that the height of the next z-step could be below due to a downward slope and/or the effect of perspective, in which case nothing is drawn. A nice property of this approach is that pixels are drawn only once!

<p align="center">
  <img width="400" src="figure_yc.png">
</p>

When the last z-step is reached, we draw a sky segment up to the top of the screen, completing the frame.

Colors are recorded along the z-step for dithering. More on this below, but first let's talk about the framebuffer!

### The framebuffer

The design generates a 640x480 VGA signal, fed into the VGA PMOD which implements a 6 bits Digital to Analog Converter (DAC). While the DAC is 6bits, we have an 8bit RGB palette internally, so if you have a better DAC, you can get the full color depth.

The VGA signal is created by the design coming with Silice: [`../common/vga.ice`](../common/vga.ice).

As the VGA signal is produced, the VGA module gives us a screen coordinates and expects a RGB color in return. We will store our framebuffer in SPRAMs, and thus have to access the memory as the VGA signal is produced (e.g. we'll be *racing the beam*).

A SPRAM is used as follows: at a given cycle we set an address and ask either to read or write -- we cannot do both at once. On the next cycle the memory transaction is done (data is available if we were reading), and we can immediately do another. So we can read or write one value every cycle, at any address. A huge luxury when it comes to memory!

As discussed earlier, we will use a single 320x200 8 bits framebuffer stored across two 32 kilobytes SPRAMs. The 8 bits of a pixel are split as 4 bits in each SPRAM. This has the advantage that both SPRAM are accessed with the same addresses: to retrieve pixel 0 we read address 0 and get the four least significant in the first SPRAM and the four most significant bits in the other.

The ice40 SPRAMs are 16 bits wide. This means that we read 16 bits at once at a given address. As we read two SPRAMs simultaneously we get 32 bits, or four 8 bits pixels. This is great, because it means that we will not have to read often from the framebuffer as the VGA signal is produced. It gets even better: our VGA signal has a 640 pixels horizontal resolution, while we want to output only 320 pixels horizontally. So we only have to read once in the SPRAMs to cover 8 screen pixels. That is one read every 8 clock cycles. During the seven other cycles the SPRAMs are free. Why does it matter? Well we also have to write the rendered image into the framebuffer!

The table below shows what happens every eight cycles. On cycle 7 we read (R) four pixels. Every two other cycles we shift (>>) the read values to obtain the next pixel. 
| 7 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| R |   |>> |   |>> |   |>> |   |R  |   |>> |   |>> |   |>> |   | R |

It is important to understand why we read on cycle 7: the SPRAM takes one cycle to retrieve the data. If we ask for pixel 0 on cycle 0 it is already too late! We need to be one cycle in advance. 

### Blocky results and interpolation to the rescue

Tbw

### Indexed color palette?

Tbw

### Dithering tricks

Tbw

## Credits

- Comanche data extraction thanks to [s-macke](https://github.com/s-macke/VoxelSpace).
- One example, downsampled from 1024x1024 to 128x128 is provided under fair use for educational purposes.
