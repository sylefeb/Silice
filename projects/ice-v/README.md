# The Ice-V: a simple, compact RV32I implementation in Silice

**TL;DR** A small CPU that can come in handy, a good place to start learning about both Silice and Risc-V.

## What is this?

The Ice-V is a processor that implements the RiscV RV32I specification. It is simple and compact (~ 170 lines without comments), yet demonstrates many features of Silice and can be useful in simple designs. It is specialized to execute code from BRAM, where the code is baked into the BRAM upon synthesis (can be a boot loader then loading from other sources). 

It is easily hackable and would be quite easy to extend to boot from SPI, execute code from a RAM, and connect to various peripherals. The example drives LEDs and an external SPI screen.

The version here runs out of the box on the IceStick ice40 1HK.

## Features
- implements the RV32I specifications
- executes instructions in 3 cycles, load/store in 4
- less than 1K LUTs with SPI-screen controller
- validates at around 70 Mz on the IceStick
- < 300 lines of commented code (~ 170 without comments)
- 1 bit per cycle shifter
- 32 bits RDCYCLE
- comes with a DooM fire demo ;)

## Testing

Testing requires a RiscV toolchain to compile code for the processor. Under Windows, this is included in the binary package from my [fpga-binutils](https://github.com/sylefeb/fpga-binutils) repo. Under macOS, you can install from Homebrew. Under Linux you will have to compile from source. See see [getting
started](https://github.com/sylefeb/Silice/blob/master/GetStarted.md) for more detailed instructions.

The build is performed in two steps, first compile some code for the processor to run:

From `projects/ice-v` (this directory) run:
```
./compile_c.sh tests/c/test_leds.c
```

Plug your board tp the computer for programming and, from the project folder run:
```
make icestick
```

On an IceStick the LEDs will blink around the center one.

Optionally you can plug a small OLED screen (I used [this one](https://www.waveshare.com/1.5inch-rgb-oled-module.htm), 128x128 RGB with SSD1351 driver).

The pinout for the IceStick is:
| IceStick        | OLED      |
|-----------------|-----------|
| PMOD10 (pin 91) | din       |
| PMOD9  (pin 90) | clk       |
| PMOD8  (pin 88) | cs        |
| PMOD7  (pin 87) | dc        |
| PMOD1  (pin 78) | rst       |

Equipped with this, you can test the [DooM fire](tests/c/fire.c) or the [starfield](tests/c/starfield.c) demos. 

For the DooM fire:

```
./compile_c.sh tests/c/fire.c
make icestick -f Makefile.oled
```

## The Ice-V design

Now that we have tested the Ice-V let's dive into the code! The [entire design](ice-v.ice) fits in less than 300 lines of Silice code (~ 170 without comments). 

A Risc-V processor is surprisingly simple! This is also a good opportunity to see some and learn about some Silice syntax.

The processor is made of three algorithms:
- `algorithm decoder` is responsible for splitting a 32 bit instruction into information used by the rest of the processor.
- `algorithm ALU` is responsible for all integer arithmetic: add, sub, shifts, bitwise operators, etc.
- `algorithm rv32i_cpu` is the main processor loop.

Let's start with an overview and thus start with the processor loop in `rv32i_cpu`.

We will skip everything at the beginning (we'll come back to that later!) and focus on the infinite loop that runs code. It has the following structure:

```c
while (1) {

    // 1. an instruction just became available
    //    setup register read

++: // wait for registers to be read 

    // 2. registers data is available, trigger ALU

    while (1) { // decode + ALU while entering the loop

        if (dec.load | dec.store) {   

            // 4. setup load/store RAM address
            //    enable store?

++: // wait for memory transaction
            
            // 5. write loaded data to register?
            //    restore next instruction RAM address
            
            break;
        
        } else {

            // 6. store result of instruction in register
            //    setup next instruction RAM address

            if (alu.working == 0) {
                break; // done
                // next instruction is read while looping back
            }
        }
    }
}
```
The loop structure is constructed such that most instructions take three cycles, with load/store require an additional one. It also allows to wait for the ALU which sometimes needs multiple cycles (shifts). Silice [has precise rules](../../learn-silice/Documentation.md#sec:execflow) on how cycles are used in control flow (while/if/else), which allows us to write the loop so that no cycles are wasted.

Let's go through this step by step. The first `while (1)` is the main processor loop. At the start of the iteration (`1.`) an instruction is available in memory, either from the boot address at startup, or from the previous iteration setup. The first thing to do is to read from the registers. In the implementation this is done with this code:
```c
// data is now available
instr       = mem.rdata;
pc          = wide_addr;
// update register immediately
xregsA.addr = Rtype(instr).rs1;
xregsB.addr = Rtype(instr).rs2;
```
Then, we wait for one cycle (`++:`) for the register values to be available at the BRAM outputs. Once the register values are available (`2.`), the decoder and ALU will start working. The ALU needs to be told it should trigger its computations at this specific cycle:
```c
alu.trigger = 1;
```
Then we enter a second `while(1)` loop. In many cases we will break out of the loop immediately, but sometimes the ALU needs to work over multiple cycles, so the loop allows to wait. Entering a loop takes one cycle, so while we enter the loop, data flows through the decoder and ALU, and their outputs are ready when we are in the loop. I'll explain later the setup between decoder and ALU.

In the loop we distinguish two cases: either a load/store has to be performed `if (dec.load | dec.store)` or else another instruction is running. Let's first consider the second case (`6.`). A non load/store instruction ran through the decoder, so we consider writing its output to a register. This is done with the following code:
```c
// commit result
xregsA.wenable = ~dec.no_rd;
xregsA.addr    = dec.write_rd;
xregsB.addr    = dec.write_rd;
```
That might seem a bit short? For instance where do we tell *what* to write? This is in fact done earlier in the algorithm, with the following code:
```c
// what do we write in register? (pc or alu, load is handled above)
int32 write_back <::  do_jump       ? (next_pc<<2) 
                    :  dec.storeAddr ? alu.n[0,$addrW$]
                    :  dec.storeVal  ? dec.val
                    :  alu.r;

// ...
xregsA.wdata   = write_back;
```
The first line (`int32 write_back <::` ...) is an expression tracker: the read-only variable `write_back` is an alias to the expression written in its definition. The second line `xregsA.wdata = write_back;` appears in the `always_before` block. This means that at every cycle, before anything else, `xregsA.wdata` is assigned `write_back`. This may be later overwritten in the algorithm, but if not that will be its value. This explains why we don't need to set this value when writing the result of the instruction to the register.

But why do that? Why not simply write this code in `6.` alongside the rest? This is for efficiency, in terms of both circuit size and frequency. If the assignment was in `6.` a more complex circuit would be generated to ensure it is only done in this specific state. This would be wasteful, and therefore it is best to always set this value. As long as we do not set `xregsA.wenable` nothing gets written anyway. This is a very important aspect of efficient hardware design, and by carefully avoiding uncessary condition your designs will be made much more efficient. Please also refer to [Silice design guidelines](../../learn-silice/Guidelines.md).

**WRITING IN PROGRESS**

Now let's go back at the beginning of `algorithm rv32i_cpu`.

The processor then instantiates what it needs to operate:

### 1. A *register file* 
This contains the 32 registers of the RiscV processor. In practice this is made of two BRAMs:
```c
bram int32 xregsA[32] = {pad(0)}; bram int32 xregsB[32] = {pad(0)};
```
The reason we use two is because we want to read two registers at once. So these two BRAMs actually always contain the same values, but at a given clock cycle we read at two different addresses:
```c
xregsA.addr = Rtype(instr).rs1;
xregsB.addr = Rtype(instr).rs2;
```

## Links

* RiscV toolchain https://github.com/riscv/riscv-gnu-toolchain
* Pre-compiled riscv-toolchain for Linux https://matthieu-moy.fr/spip/?Pre-compiled-RISC-V-GNU-toolchain-and-spike&lang=en
* Homebrew RISC-V toolchain for macOS https://github.com/riscv/homebrew-riscv
* FemtoRV https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV
* PicoRV  https://github.com/cliffordwolf/picorv32
* Stackoverflow post on CPU design (see answer) https://stackoverflow.com/questions/51592244/implementation-of-simple-microprocessor-using-verilog
