# Wildfire / Inferno memory map

The memory is using the following organization. There is some inheritance from prior iterations, so this may no longer be the most sound approach. In particular, each of the four sections below used to be in a same SDRAM bank, while now the controller is pipelined and interleaves bank addresses.

Nevertheless, here is what we have:

SDRAM memory addresses are 26 bits. We have the following organization:
- [0x0000000 - 0x0077FFF]() Framebuffer 0
- [0x1000000 - 0x1077FFF]() Framebuffer 1
- [0x2000000 - 0x200FFFF]() Code (fast memory)

Everything else is free to be used!

The framebuffers occupy addresses up to 77FFF in their segments. This might seem surprising: a frame is 640x480 so one would expect 4AFFF. Well, this is because the rows of 640 pixels are stored apart from each other, with a total spacing of 1024 bytes. This allows a pixel address to be computed as `x + y<<10`. But you are free to  squeeze other data in the [480-1023] unused space, the framebuffer does not touch it.

Where will the CPU code endup? This is specified in `config_cpu0.ld`. The default address is 0x2000000. Note that this address matches both [the CPU boot address](../wildfire.si) and the start of the [fast memory segment covered by BRAM](../wildfire.si). The fast memory segment typically has a size of [65536 bytes](../ash/bram_segment_ram_32bits.si) but this can be configured (beware that a larger BRAM may reduce fmax, but a smaller one increases it slightly). If the code goes out, no worries, it will slow down (a lot!) but fallbacks to SDRAM.

Note that the code is shifted by 512 bytes so the stack starts at 0x20001ff (it grows downwards). See [crt0.s](../smoke/crt0.s). This shift is there to ensure that the stack also is in the fast memory segment.
