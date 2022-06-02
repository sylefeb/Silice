# Ice-V projects: exploring RISC-V implementations in Silice

> **Goal**: Exploring how to design RISC-V processors in Silice, with a focus on:
> - simple designs (easy to read source code with explanations, easy to hack)
> - compact designs (fit on small FPGAs, e.g. HX1K (icestick) and UP5K (icebreaker))
> - adventurous designs (dual core, pipelined, etc.)
> - fun demos! (graphics, sound, etc.)

The CPUs you'll find here should work great as microcontrollers for your projects,
but most are focused on executing from BRAM with the exception of the *Fermata*
(see list below).

The Ice-V projects come with their own custom SOCs, but if you only want to add
RISC-V capabilities to your designs and are not so much interested in playing
the CPU itself, check out the [easy_riscv demo projects](../easy-riscv/README.md).

All the CPUs run code compiled with gcc RISC-V (build scripts included), and
come with a SOC with a SPI-screen driver (some have SPIflash and even sound!).
For each variant the CPU is in the [CPUs](./CPUs/) subdirectory, the SOC is in
the [SOCs](./SOCs/) subdirectory, the compilation scripts in
the [compile](./compile/) subdirectory. All can be simulated using verilator,
with a graphical output (SPI-screen emulation). For details, see the variants
and their associated pages below.

The Ice-V project contains the following CPUs (and corresponding SOCs/demos):
- The [IceV](IceV.md)
    - RV32I CPU
    - fits easily on the HX1K/icestick (~1000 LUTs with its SOC)
    - ~300 lines of commented code (~100 lines compacted)
    - validates at around 65 MHz on the icestick
    - load/store in 4 cycles, instructions in 3 cycles but for shifts which
      additionally take one cycle per shifted bit (to save LUTs)
    - 32 bits `rdcycle`
- The [IceV dual](IceVDual.md)
    - two RV32I cores for little more LUTs!
    - fits on the HX1K/icestick (~1240 LUTs with its SOC)
    - each instruction takes exactly 4 cycles, cores are interleaved: one instruction
    executes every 2 cycles (core 0, core 1, core 0, ...)
    - ~450 lines of commented code (~120 lines compacted)
    - validates at around 60 MHz on the icestick
    - 32 bits `rdcycle`, optional support for mul, div
    - features a 'road racing' and 'fractal' demo
    - used in the [doomchip-onice](https://www.antexel.com/doomchip_onice_rc3/)!
- The [IceV dual fermata](IceVDualFermata.md)
    - same as the IceV dual, but with a more general memory interface
    - targeted at the UP5K/icebreaker (~2800 LUTs with its SOC)
    - cores have independent memory interfaces
    - RAM (SPRAM, 128KB), ROM (SPIflash), framebuffer (320x200, 1bpp)
    - a core can keep going while the other is waiting on a memory fetch
    - features a cool tunnel demo
- The [IceV conveyor](CPUs/ice-v-conveyor.si)
    - single RV32I core, but pipelined! (no data bypass, so far from full pipeline speed)
    - ~400 lines of commented and explained code
    - fits on the HX1K/icestick (~1270 LUTs with its SOC)
    - validates at around 60 MHz on the icestick
    - 24 bits `rdcycle`
- The [IceV swirl](CPUs/ice-v-swirl.si)
    - single RV32I core, but pipelined with data bypass!
    - ~450 lines of commented and explained code
    - targeted at the UP5K/icebreaker (~1795 LUTs with its SOC)
    - validates at around 25 MHz on the icebreaker
    - 32 bits `rdcycle`, optional support for mul, div
