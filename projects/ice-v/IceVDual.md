# The Ice-V-dual: a compact dual-core RISC-V RV32I implementation in Silice

**Note: writing in progress**

The Ice-V-dual is a dual core version of the [Ice-V](README.md). It contains *two*
RV32I cores that work independently but share the RAM (code + data). Like 
the Ice-V it is specialized to run from BRAM. 

With its SoC it uses 1250+ LUTs on the IceStick and validates at ~55 MHz. 
Each core is 4 cycles per instruction but for shifts (both cores wait if one does 
ALU shifts). Cores retire instructions with a 2 cycles delay between them. 
`rdcycle` is supported with a 31 bits counter, the LSB of `rdcycle` returns the CPU id.

<p align="center">
  <img src="ice-v-dual-demo.png">
</p>


## How is this possible?

It would seem that two CPUs should use twice the resources as one? Well not quite.
If we look carefully at the execution pattern of the Ice-V there are times where 
parts of the logic is not used. This opens an interesting opportunity: could
we squeeze a second CPU (let's call it a second *core*) and use this logic when its free?

It turns out that yes, we can! But before we describe this in more details, let's
first recall the Ice-V execution pattern. It comprises four states:
1. `F` (fetched) when a next instruction becomes available. This requests registers
from the instruction.
2. `T` (trigger) when the register become available. This triggers the decoder and ALU.
3. `LS1` (load-store 1) on a *load or store* this sets up the memory address and read/write mask.
4. `LS2/C` (load-store 2 / commit) this completes any pending load-store, commits
any pending result to registers (*write back*) and sets up the memory address
to fetch the next instruction.

Note that we ignore here the special case of waiting for the ALU (on shifts). Let's
leave this aside for now, we'll come back to it later.

In the Ice-V, `LS1` is skipped when the instruction is not a load-store, resulting
in a pattern of 4 cycles for load-stores and 3 cycles for others. That's trying
to be as fast as possible, however making the pattern always 4 cycles open interesting
opportunities. So let's consider the case where `LS1` is always done (and does nothing
if the instruction is *not* a load-store).

We get a clean, simple 4-cycles sequence: `F`, `T`, `LS1`, `LS2/C`.
The main resources used by the CPU are the BRAM (storing code+data), the registers
(in a separate BRAM, we'll simply refer to it as the 'registers' to avoid confusion),
the decoder+ALU. If we are to have two cores in a small design, they can at best 
share the BRAM and the decoder+ALU. They need their own registers anyway (so
that execution context is independent).

Can we somehow reuse the BRAM and decoder+ALU? Let's tag when the resources are
accessed. This happens in between the steps as the clock ticks (accessed resources in parentheses):

 |(bram) | `F` | (regs) | `T` | (d+ALU) | `LS1` | (bram) | `LS2/C` | .. |
 | --- | --- | --- | --- | --- | --- | --- | --- | --- |

(this cycles indefinitely).

Obviously, a second core could not be aligned with the same pattern. However, if 
we simply shift two cycles, we get this:

| *core 0* |..|(bram) | `F` | (regs) | `T` | (d+ALU) | `LS1` | (bram) | `LS2/C` | .. |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| *core 1* |..| (d+ALU) | `LS1` | (bram) | `LS2/C` | (bram) | `F` | (regs) | `T` | .. |

See how in each column we get different resources every time, BRAM in particular? That's exactly what we want. Also note how the execution states become paired, we have either `F` / `LS1` or `T` / `LS2/C`. From this we can make the following table, which outlines the four possible execution stages:

| *stage*    | `F`__ | `T`__ | `LS1` | `LS2/C` |
| ---------- | --- | --- | ----- | ------- |
| 0          |  0  |  .  |   1   |   .     |
| 1          |  .  |  0  |   .   |   1     |
| 2          |  1  |  .  |   0   |   .     |
| 3          |  .  |  1  |   .   |   0     |

In fact, only two states in the FSM are really necessary (`F` / `LS1` and `T` / `LS2/C`) as indicated by the parity of *stage*. Which core is active is then
indicated by the most significant bit of *stage*.