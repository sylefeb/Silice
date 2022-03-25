# The Ice-V-dual *fermata*
*dual-core, dual-memory interface RISC-V RV32I*

The Ice-V-dual *fermata* is a dual memory interface version of the [Ice-V dual](IceVDual.md). This means both cores can independently access memory, so if one is waiting the other is free to proceed (e.g. one core waiting for slow SPIflash while the other keeps executing from BRAM).

> *Fermata* is a musical term that refer to the prolongation of a note. This is what the ice-v fermata does, prolongating instructions while memory is busy. However, the *tempo* never stops and the internal state of the processor keeps going.

The ice-v dual was designed around BRAM, assuming that memory can answer to a request in a single cycle. It therefore never waits for memory. The problem of course is that more complex memories have latency, and require pauses while data is being loaded.

While the original ice-v dual would not pause on memory accesses, it could pause on a busy ALU. Because the same ALU is shared between the cores this implies pausing *both* cores, interrupting the tempo: the processor state is no longer refreshed. This means that both cores are frozen until the ALU is done, as if time had ceased to pass.

> **Note:** The ALU only needs additional cycles when shifts are performed at 1 bit per cycle, avoiding a barrel shifter that uses many LUTs. This is the default ; however setting `ICEV_FAST_SHIFT=1` will produce a barrel shifter eliminating pauses. The ice-v also has mul/div support (not full RV32IM support yet), which can be enabled by setting `ICEV_MULDIV=1`. Divisions also require multiple cycles and will pause both cores.

The way the ALU pauses is not something desirable for pausing on memory accesses. In most SOCs, the memory will be composed of fast and slow types of memory (BRAMs, SPRAMs, SDRAM, DDR, SPIflash, etc.), possibly with caches in between. If everytime one core starts accessing slow memory the other is also slowed down, we'll significantly degrade performance.

A better mechanism is required, which led to the *fermata* design. This requires two ingredients:
- A way for cores to prolong an instruction while waiting for memory.
- Two separate memory interfaces so that one can keep going while the other is waiting.

It might seem that having two memory interfaces means the cores are in different memory spaces. However, with a carefully designed memory controller we can ensure that both cores live in a same, consistent memory space while allowing one to keep executing from fast memory while the other is waiting on slower memory accesses.

Let's dive into the details!

> **To be continued**
