# The Fire-V RV32I core

Source code: [fire-v.ice](../fire-v/fire-v.ice).

**Note:** *The code is still rough, Needs cleanup and comment.*

**Note:** *This document is a work in progress, for now I focus on the overview, will expand with a code walkthrough soon.*

## Overview

Fire-V is an example RV32I core written in [Silice](../../). While simple to read and understand, it has some interesting and hopefully useful characteristics:
- Compromise between (in this order): fmax, simplicity and compactness.
- Passes timing at 90 MHz (100 MHZ depending on environment), overclocked in a framework at 160 MHz on the ulx3s, and still working fine at 200 MHz in isolation.
- Assumes a memory controller with unknown latency, plugs easily to e.g. an SDRAM controller.
- Predicts next fetched address and indicates whether prediction was correct. The memory controller may exploit this prediction to reach as low as two cycles per instruction in coherent flow. Branches are not predicted.
- Registers in BRAM
- Barrel shifter for 1 cycle ALU, implements 32 bits `rdcycle` and `rdinstret`, as well as a special `userdata` hijacking `rdtime` (used as a mechanism to feed auxiliary data to running code).
- Relatively compact, ~2K LUTs on ECP5 (2005 LUTs as of latest).
- Dhrystone CPI: 4.043

**Note:** *While I am quite happy with these results, there are way smaller RISC-V cores out there (SERV / PicoRV / FemtoRV) and faster ones with pipelined and multiscalar architectures. Nevertheless it is quite capable and provides a fun CPU to play with. Also, it is written in Silice :-)*

## Operation

The processor is organized in a main loop with four main states:

```c
always {
  
  switch (case_select) {

    case 8: { /* refetch */  }

    case 4: { /* load / store */  }

    case 2: { /* ALU / fetch */ }

    case 1: { /* commit + decode */ }

    default: { /*wait*/ }

  }
  
}
```

Let's see how the processor operates under various scenarios.

### Ideal case

The Fire-V executes a coherent flow of instructions as follows, assuming the memory controller is capable of sending a prefetch instruction in two cycles (which is the case of the [BRAM fast-mem segment](../ash/bram_segment_ram_32bits.ice)).

Each column is a cycle, time goes left to right:
|  ALU / fetch    | commit / decode  | ALU / fetch      | commit / decode |
| -------------   | -------------    | ---------------- |---------------- |
| In: `instr i+1` | In: Regs `i+1`   | In: `instr i+2`  | In: Regs `i+2`  |
| ALU `i`         | decode `i+1`     | ALU `i+1`        | decode `i+2`    |
|                 | commit `i`       |                  | commit `i+1`    |
| setup regR `i+1`| setup regW `i`   | setup regR `i+2` | setup regW `i+1`|
| fetch `i+2`     | setup ALU `i+1`  | fetch    `i+3`   | setup ALU `i+2` |
| predict `i+3`   |                  | predict  `i+4`   |                 |

- decode: examines the instruction and sets everything up for the next steps
- ALU: arithmetic unit and comparator are running
- commit: result from ALU and comparator are examined to decide what to do next
- setup regR: setup reading registers (from dedicated BRAM)
- setup regW: setup writing registers (into dedicated BRAM)
- In: means something becomes available, either instructions (from RAM) or registers (from dedicated BRAM).

Note how the ALU has a full cycle to operate, with both inputs and outputs registered. This explains the fmax and - I think - the robustness to overclocking.

### Slow memory

If the memory cannot follow (e.g. SDRAM) cycles are wasted waiting for data to come in just before the ALU/prefetch stage in the diagram above (waiting for *In: `instr n`*).

### Branches and jumps

On a jump, the next instruction prediction is incorrect and breaks the execution flow, here is what happens:

| commit / decode        | Refetch         | (+1)  | ALU / fetch      | commit / decode | ALU / fetch      | commit / decode |
| -------------          | ----------------| ---   |----------------  |---------------- |----------------  |---------------- |
| In: Regs `i+1`         |                 |       | In: `instr j`    | In: Regs `j`    | In: `instr j+1`  | In: Regs `j+1`  |
|                        | fetch `j`       |       |                  |                 |                  |                 |
| decode `i+1`           |                 |       | ALU `-`          | decode `j`      | ALU `j`          | decode `j+1`    |
| commit `i` **(jump!)** |                 |       |                  | commit `-`      |                  | commit `j`      |  
| setup regW `i`         |                 |       | setup regR `j`   | setup regW `-`  | setup regR `j+1` | setup regW `j`  |
| setup ALU `i+1`        |                 |       | fetch `j+1`      | setup ALU `j`   | fetch `j+2`      | setup ALU `j+1` |
| predict `j`            | predict `j+1`   |       | predict `j+2`    |                 | predict `j+3`    |                 |

As you can see some cycles are wasted to recover from the break in the flow. The refetch step interrupts everything, and resumes from a different address. In the current framework, it typically take 6 cycles: 1 for refetch, 1 to obtain `instr j`, and then 2 steps of *ALU / fetch* and 2 of *commit / decode*. So these are 4 cycles in excess of the best case scenario of 2 cycles. (Of course assuming a memory that can use the predictions ; these timings are for a BRAM memory cache).

### Load / store

When a load store occurs we also have to interrupt the execution flow. However we can do a bit better by playing tricks with the predictions.

| commit / decode        | Refetch         | (+1)  | Load / store     | commit / decode   | ALU / prefetch   |
| -------------          | ----------------| ---   |----------------  | ----------------  |----------------  |
| In: Regs `i+1`         | In: `instr i+2` |       | In: `data d`     |                   | In: `instr i+3`  |
|                        | fetch `d`       |       |                  |                   |                  |
| decode `i+1`           | ALU `i+1`       |       |                  |  decode `i+2`     | ALU `i+2`        |
| commit `i` **(load/store!)** |           |       |                  |  commit `i+1`     |                  |
| setup regW `i`         | setup regR `i+2`|       | setup regW (load)|  setup regW `i+1` | setup regR `i+3` |
| setup ALU `i+1`        |                 |       | fetch `i+3`      |  setup ALU `i+2`  | fetch `i+4`      |
| predict `d`            | predict `i+3`   |       | predict `i+4`    |                   | predict `i+5`    |

In this case, 4 cycles are required to perform the *load / store*, as we keep other things running in parallel.
(Again assuming a memory that can use the predictions ; these timings are for a BRAM memory cache).

### Register conflicts

Things can go wrong due to one important detail. I am using BRAM for registers, and even though this is a simple-dual BRAM, reading and writing at the same address at the same cycle is problematic: the read will not see the result of the write. This is an issue during a *load /store*, as the values we read for the `i+1` and `i+2` registers may not reflect the result of the store for instruction `i`. In such cases we have to issue a refetch in the middle of the *load / store*, triggering a refetch. I call this event a *register conflict*. In such instances we pay a whopping 11 cycles ; that is fortunately rare (0.6% of instructions on Dhrystone), but I guess one could build pathological cases.

## Notes and thoughts

**Branch prediction.** It seems this could be possible, as during *commit / decode* we have the instruction and can figure out what is going to happen. I made just a few tests, but left this for later -- impact on fmax and code complexity is unclear.

**BRAM size and fmax.** In most designs now, the BRAM size becomes the limiting factor, possibly due to the address decoder being generated -- and of course the pressure of fetching the predicted address in two cycles. On the ULX3S, fmax validates at 90 MHz with a 65536 bytes BRAM (16 KB of integer code), but above that fmax falls to around 80 MHz. However, keep in mind that [Wildfire](../README.md) falls back to SDRAM outside of the fast BRAM memory range, so this is only a matter of speed, there is plenty of memory!

**Removing one cycle from load/store.** This would be possible if the memory controller is interruptible: right now, when a jump occurs during *commit / decode* we cannot immediately tell the memory controller to change the address being fetched. That is because I am assuming a controller that cannot be interrupted. Possibly room for improvement here?
