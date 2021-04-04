# Tiny terrain renderer on ice40 UP5K

This project is a recreation in FPGA hardware of the classic Voxel Space terrain renderer featured in games such as [Comanche](https://en.wikipedia.org/wiki/Comanche_(video_game_series)). 

It was developed and tested on an IceBreaker board with VGA PMOD.

## How to test

Plug your board, then from a command line in this directory `./build.sh`

## Revisiting the Voxel Space algorithm in hardware

The main principle of the terrain renderer is similar to the Voxel Space
renderer. This [github repo by s-macke](https://github.com/s-macke/VoxelSpace) gives an excellent overview of the algorithm. I will not repeat this here and instead focus on the specificities of my implementation, as well as the hardware elements.

## Memory considerations

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

## Interpolation to the rescue

Tbw

## Indexed color palette?

Tbw

## Dithering tricks

Tbw
