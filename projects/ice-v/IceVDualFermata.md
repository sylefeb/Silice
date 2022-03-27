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

## Memory interface

Since we are using a more elaborate memory, we need to define its interface.
There are various ways this can be done, but after various approaches I settled
on the one below, which essentially adds the `req_valid` and `done` signals
to the interface.

```c
interface icev_ram_user {
  output!  addr,      // memory address
  output!  wenable,   // write enable (one bit per byte)
  output!  wdata,     // data to be written
  input    rdata,     // data read from memory
  output!  req_valid, // pulses high when request is valid
  input    done,      // pulses high when request is completed
}
```

Note the use of `output!` (with a `!`) to indicate that the outputs are not
registered: the parent unit (memory controller) immediately sees changes to it.

## Processor

The ice-v takes four different stages in succession, over four cycles. In the table
below `0` indicates core 0 and `1` indicates core 1.

| cycle | *stage*    | `F`&nbsp;&nbsp; | `T`&nbsp;&nbsp; | `LS1` | `LS2/C` |
| ----- | ---------- | --- | --- | ----- | ------- |
| i     | 0 (2b00)   |  0  |  .  |   1   |   .     |
| i+1   | 1 (2b01)   |  .  |  0  |   .   |   1     |
| i+2   | 2 (2b10)   |  1  |  .  |   0   |   .     |
| i+3   | 3 (2b11)   |  .  |  1  |   .   |   0     |

Each core expects data from memory at stages `F` (next instruction is expected)
and stage `LS2/C` (on `LS2`, result from a load). Our goal is to allow the stages
to run freely, but do nothing when the last requested memory transaction is not yet available.

First, we need to ensure the cores do not miss new data coming in. To this end
we create a set of variables and trackers:
```c
  // did we receive new data?
  uint1                  reqmem0_was_done(0);
  uint1                  reqmem1_was_done(0);
  uint1 reqmem0_done <:: reqmem0_was_done | :mem0.done; // combines current with past
  uint1 reqmem1_done <:: reqmem1_was_done | :mem1.done;
  // ...
  // (near the end)
  reqmem0_was_done = mem0.req_valid ? 0 : (mem0.done|reqmem0_was_done);
  reqmem1_was_done = mem1.req_valid ? 0 : (mem1.done|reqmem1_was_done);
```

## Memory controller

...


## Linker script and startup

...

> **To be continued**
