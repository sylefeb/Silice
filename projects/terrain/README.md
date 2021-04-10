# Tiny terrain renderer on ice40 UP5K

This project is a recreation in FPGA hardware of the classic Novalogic Voxel Space terrain renderer featured in games such as [Comanche](https://en.wikipedia.org/wiki/Comanche_(video_game_series)). 

It was developed and tested on an [IceBreaker board](https://1bitsquared.com/collections/fpga/products/icebreaker) with a Digilent VGA PMOD.

### **How to test**

In addition to Silice, a RISC-V environment is needed, see [Getting Started](../../GetStarted.md).

- **With an Icebreaker**: plug your board, then from a command line in this directory `./build.sh`
- **In simulation**: from a command line in this directory `./simul.sh` ; this requires the [Verilator framework](../../GetStarted.md).

### **Design files**

- [`main.ice`](main.ice) is the main framework
- [`terrain_renderer.ice`](terrain_renderer.ice) is the hardware renderer
- [`firmware.c`](firmware.c) is the RISC-V firmware code

For more details on the Risc-V implementation see the [fire-v project](../fire-v/).

## Revisiting the Voxel Space algorithm in hardware

The main principle of the terrain renderer is similar to the Voxel Space
renderer. The [github repo by s-macke](https://github.com/s-macke/VoxelSpace) gives an excellent overview of the algorithm. I give below some explanations to make this README self-contained but please checkout [s-macke](https://github.com/s-macke/VoxelSpace)'s page for more details and illustrations.

### **First, some memory considerations**

A first challenge in fitting this on an UP5K is the limited memory. A terrain renderer typically uses a large amount of memory to store the terrain data: elevation and color map. 

Our UP5K FPGA features two types of specialized memories: BRAM ([Block RAM](https://www.nandland.com/articles/block-ram-in-fpga.html)) and SPRAM (Single Port RAM). These are very fast, returning a value in a single clock cycle, but they are also in limited supply: we have 128 kilobytes in four SPRAMs (each 32 kilobytes), plus 120 kilobits (*bits* not *bytes*) of dual-port BRAM. That's not much. In contrast, a single map of the original Comanche game is 2 megabytes (color + height), and a 320x200 framebuffer is already 64 kilobytes (320 x 200 x 8 bits for a 256 colors palette).

Of course we can always downsample the maps, and we will do just that, using maps of 128x128 pixels. However the loss in resolution is extreme, and the results on screen would be far from pleasing using the original algorithm. So we cannot stop there, we need some tricks. In particular, we will resort on both interpolation and dithering. More on that later.

Many rendering algorithms require two framebuffers: one is displayed while the next frame is drawn in a second buffer,  hidden from view. This is called *[double buffering](https://en.wikipedia.org/wiki/Multiple_buffering)*. It is important when, for instance, the previous view has to be cleared before drawing afresh. However, our terrain renderer draws the view from front to back, allowing to use a single framebuffer. As the next frame is quite similar to the previous one (the viewpoint changes progressively), the difference will not produce perceivable flickering as the frame is drawn in front of our eyes, apart from a potential screen tearing effect.
This means we can allocate 64 kilobytes to a single full 320x200 8 bits framebuffer. (*Note:* a first version was using two 4 bits framebuffers, and it was looking quite good! but the extra color depth can be useful for future extensions and a more varied terrain.)

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

### **Algorithm overview**

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

### **The framebuffer**

The design generates a 640x480 VGA signal, fed into the VGA PMOD which implements a 6 bits Digital to Analog Converter (DAC). While the DAC is 6 bits, we have an 8 bits RGB palette internally, so if you have a better DAC, you can get the full color depth.

The VGA signal is created using the VGA controller provided with Silice: [`../common/vga.ice`](../common/vga.ice).

As the VGA signal is produced, the VGA module gives us screen coordinates and expects a RGB color in return. We will store our framebuffer in SPRAMs, and thus have to access the memory as the VGA signal is produced (e.g. we'll be *racing the beam*).

An SPRAM is used as follows: at a given cycle we set an address and ask either to read or write -- we cannot do both at once. On the next cycle the memory transaction is done (data is available if we were reading), and we can immediately do another. So we can read or write one value every cycle, at any address. A huge luxury when it comes to memory!

As discussed earlier, we will use a single 320x200 8 bits framebuffer stored across two 32 kilobytes SPRAMs. The 8 bits of a pixel are split as 4 bits in each SPRAM. This has the advantage that both SPRAM are accessed with the same addresses: to retrieve pixel 0 we read address 0 and get the four least significant in the first SPRAM and the four most significant bits in the other.

The ice40 SPRAMs are 16 bits wide. This means that we read 16 bits at once at a given address. As we read two SPRAMs simultaneously we get 32 bits, or four 8 bits pixels. This is great, because it means that we will not have to read often from the framebuffer as the VGA signal is produced. It gets even better: our VGA signal has a 640 pixels horizontal resolution, while we want to output only 320 pixels horizontally. So we only have to read once in the SPRAMs to cover 8 screen pixels. That is one read every 8 clock cycles. During the seven other cycles the SPRAMs are free. Why does it matter? Well we also have to write the rendered image into the framebuffer!

The table below shows what happens every eight cycles. On cycle 7 we read (R) four pixels. Every two other cycles we shift (>>) the read values to obtain the next pixel. 
| 7 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| R |   |>> |   |>> |   |>> |   |R  |   |>> |   |>> |   |>> |   | R |

It is important to understand why we read on cycle 7: the SPRAM takes one cycle to retrieve the data. If we ask for pixel 0 on cycle 0 it is already too late! We need to be one cycle in advance. 

### **Blocky results and interpolation to the rescue**

If implemented as described so far, the results would be very blocky:
<p align="center">
  <img width="400" src="no_interp.png">
</p>

This, of course, is due to the low 128x128 resolution of the height map and color map. In computer graphics (and many other fields!) the first thing that comes to ming is 'let's interpolate the data!'. Btw, this was one of the huge steps forward when GPU were introduced. I vividly remember the jump in quality between the *Tomb Raider* software renderer and the *3dfx* one -- a lot of it was due to the nice smooth bi-linear texture interpolation! So, we know what to do, let's interpolate.

Interpolating the z-coordinates is relatively straightforward, and in this axis aligned version, we actually only have to interpolate between two samples during the x traversal of each z-step (but the code has a full bi-linear traversal commented out, for future use ;) ). The linear interpolator is simply:

```c
algorithm interpolator(
  input  uint8 a,
  input  uint8 b,
  input  uint8 i,
  output uint8 v
) <autorun> {
  always {
    v = ( (b * i) + (a * (255 - i)) ) >> 8;
  }  
}
```

This take 8 bits values `a` and `b` and another 8 bit interpolator `i`. It outputs an 8 bits `v` such that `v == a` if `i == 0` and `v == b` if `i == 255`. In fact, linear interpolation is indeed very simple (and gets nicely mapped to DSP blocks by Yosys!).

Here is the linear interpolation applied to the view above:
<p align="center">
  <img width="400" src="z_interp.png">
</p>

Much better! But what about the colors?

### **Interpolating indexed colors?**

Interpolating z-heights is relatively simple, but what about colors? If we were using true RGB pixels that would be exactly the same. But that is a huge luxury that we can't really afford, can we? (plus, even if we could, I very much prefer 8 bits palette graphics! yeah I know, nostalgia). 

The reason we cannot easily interpolate colors is because each value we retrieve from the map is an 8 bits index in a 256 entries color map. Interpolating the indices makes no sense, see for yourself, here is the color palette:

<p align="center">
  <img width="200" src="palette.png">
</p>

As it lacks any order, selecting a color in between two others makes little sense. Of course, some palette can be carefully designed to support interpolation (*Doom 1994* does [amazing palette tricks](https://fabiensanglard.net/gebbdoom/) for lighting), but here that is not the case.

So what can we do? Well, we can rely on a different kind of interpolation, called *dithering*. You are likely already very familiar with dithering -- well at least your eyes are! -- because this is the technique used by printed newspapers and inkjet printers. The idea is to give the illusion of a gradient even though only few colors are available. This works by interleaving point spreads of the different colors, such that locally the proportion (as seen in a small neighborhood) give the correct average. Dithering and stippling are huge topics on their own, but here we will be using a simple old-shool technique, specifically [ordered dithering](https://en.wikipedia.org/wiki/Ordered_dithering) with a Bayer matrix. 

These are fancy names to describe a simple idea: instead of *computing* an intermediate value between `a` and `b` based on `i` (e.g. `(a+b)/2` if `i` is 127) we will *select* either `a` or `b` with a probability based on `i` (e.g. for `i == 127` -- half way -- we will select  `a` or `b` with equal probability, while `i == 0` will always select `a`).

Dithering is very effective, see for yourself!

<p align="center">
  <img width="400" src="all_interp.png">
</p>

Now there is one complication here. As we walk along the x-axis we can easily select between the two colors (corresponding to the two maps pixels we are in-between). However, vertically (on-screen) we need to interpolate between the previous color along the z-step and the current color that has been select by dithering. That is why we have a second array `c_last` storing color for the previous z-step. And this is it! We now have a nicely smooth terrain, with the cool old-school dithering touch.

The dithering Bayer matrix is stored in code:

```c
  // 8x8 matrix for dithering  
  // https://en.wikipedia.org/wiki/Ordered_dithering
  int6 bayer_8x8[64] = {
    0, 32, 8, 40, 2, 34, 10, 42,
    48, 16, 56, 24, 50, 18, 58, 26,
    12, 44, 4, 36, 14, 46, 6, 38,
    60, 28, 52, 20, 62, 30, 54, 22,
    3, 35, 11, 43, 1, 33, 9, 41,
    51, 19, 59, 27, 49, 17, 57, 25,
    15, 47, 7, 39, 13, 45, 5, 37,
    63, 31, 55, 23, 61, 29, 53, 21
  }; 
```

It is accessed first between x-axis colors:
```c
l_or_r      = bayer_8x8[ { y[0,3] , x[0,3] } ] > l_x[$fp-6$,6]; // horizontal
```

and then between y(screen)-axis vertical colors:
```c
t_or_b      = bayer_8x8[ { x[0,3] , y[0,3] } ] < v_interp[4,6]; // vertical
```

Note how in both cases the screen `x` and `y` coordinates are used to access the matrix -- this is done for better visual temporal coherence. Then the value in the matrix is compared to the interpolation threshold, which is used used to decide  which of three colors to select: left/right of the new z-step, or the color from the previous step.

```c
clr         = l_or_r ? ( t_or_b ? h00[8,8] : c_last.rdata ) : (t_or_b ? h10[8,8] : c_last.rdata);
```

### **Where's all the data?**

Almost done! That's quite a few details for such a small piece of code ;)

So what's left? Well, the SPRAMs are great, but contrary to BRAMs they cannot be initialized from the FPGA configuration bitstream. So, how are we going to put the height map and color data their in the first place?

Here I went a bit overboard by adding a complete RISC-V CPU to the design just to do that. I known, total overkill but that is so easy!! Silice comes with a choice of RISC-V implementations and here I used the [fire-v](../fire-v/), just because it was ready, simple and fit the hardware (*Note:* I am working on a compatible version of the [ice-v](../ice-v/) which is much smaller and would be enough here). 

### **Conclusion**

I hope you enjoyed revisiting this algorithm with a hardware twist! I surely did. I'll keep improving these explanations, so please feel free to send me comments. You can reach me on github or twitter, [@sylefeb](https://twitter.com/sylefeb).

## Credits

- Comanche data extraction thanks to [s-macke](https://github.com/s-macke/VoxelSpace).
- One example, downsampled from 1024x1024 to 128x128 is provided under fair use for educational purposes.
