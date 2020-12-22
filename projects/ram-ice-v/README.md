# risc-v RV32I in SDRAM with graphics, sound and sdcard

The purpose of this project is to demonstrate how the various components 
defined with Silice can be composed into a fully fledged small computer (with multiple CPUs!).

The two main designs are:
- (video_rv32i.ice)[video_rv32i.ice] A single processor design.
- (video_dual_rv32i.ice)[video_dual_rv32i.ice] A dual processor design with audio!

This comes with a miminimalistic 'libc' providing the basics such as printf and 
timing (cycles) queries. 

**Note** This is still work in progress, this documentation will improve in the coming days.

## Overall architecture

The graphics framework is targetting boards with HDMI/VGA and SDRAM. This is typically
the ULX3S or the de10nano with a (MiSTer)[https://github.com/MiSTer-devel/Main_MiSTer/wiki] setup.

*Note*: This project has been only tested with the ULX3S thus far.

Here is a diagram of the architecture with the main modules. Note how the Silice
code below makes it very easy to assemble this architecture from pieces.



The CPUs run at 50 MHz, while the external SDRAM interface runs at 100MHz and the HDMI controller at 125MHz. 

## The SDRAM controller and arbitrer


## The instruction 'cache'

The core issue with fitting the design in a full framework built around SDRAM is that
the bandwidth is shared, and somewhat pressured by the framebuffer. This is particularly
a problem when fetching instructions, as each could take many cycles (10+) to become available. To mitigate this, I created a small component, (basic_cache_ram_32bits.ice)[basic_cache_ram_32bits.ice] which sits between the CPU and the SDRAM interface. It implements a naive cache mechanism where read and writes are remembered in a memory space covering the program instructions and stack. Good out of the cached space is safe, but slow. 

The cache relies on simple dualport BRAMs to allow for the cache content to be updated, while starting to fetch the next instruction, which we know is very likely to be the one required. This, together with the CPU design itself, allows to process instructions in as little as two cycles.

## The RiscV processor

This is a RV32I design. It has no fancy features, and is meant to remain simple
and easy to modify / hack. Its most 'advanced' feature is that it tries to 
optimistically fetch the next instruction before being done with the current one.
Together with the instruction cache, this allows many instructions to execute in
only 2 cycles. 

The design is not optimized for compactness, for that please checkout the (ice-v)[../projects/ice-v] which implements an RV32I fitting on an IceStick! (~1182 LUTs with OLED
controller).


## Links

- Voices made with https://text-to-speech-demo.ng.bluemix.net/


