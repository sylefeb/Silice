# The DooM-chip

*It will run Doom forever*

## Foreword

This is very much a work in progress, and Silice has evolved together with the DooM-chip. Therefore the code is not always using of the latest language niceties.

It is also slow compared to what it should be, as the main loop is way too sequential. This will be improved and optimized (resulting in a much more elegant code!) but only once all features are in. First, let's make it work!

## Where's All the Data?

For obvious copyright reasons you have to provide your own Doom WAD file. During compilation the data will be automatically extracted and processed. You can select the level in the header of *vga_doomchip.ice*.

## How to test

Open a shell, go to *Silice/projects/build/verilator* and then type in
```./verilator_sdram_vga.sh ../../vga_doomchip/vga_doomchip.ice```

Images will be produced in the directory, the third one (*vgaout_0002.tga*) should reveal a view of E1M1! (the two first are black as this corresponds to memory and chip reset/warmup).

## Running on real hardware

The target platform is a de10-nano board equipped with SDRAM.  This is the
exact same setup as the [MiSTEr projet](https://github.com/MiSTer-devel/Main_MiSTer/wiki) (see instructions there).
You also need a VGA DAC, see [instructions here](../DIYVGA.md).

I cannot provide a pre-built image for programming the FPGA as it would include
game data, so you'll have to compile the entire thing -- but that is a good way
to get started, and I will guide you through the process!

To be continued...
