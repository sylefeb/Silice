# The Ice-V: a simple, compact RISC-V RV32I implementation in Silice

**TL;DR** A small CPU design that can come in handy, a detailed code walkthrough, a good place to start learning about both Silice and RISC-V.

**Please note:** (2021-06-19) The walkthrough is out of sync as I just made many improvements to the design. Will update soon!

## What is this?

The Ice-V is a processor that implements the [RISC-V RV32I specification](https://github.com/riscv/riscv-isa-manual/releases/download/Ratified-IMAFDQC/riscv-spec-20191213.pdf). It is simple and compact (~160 lines without comments), demonstrates many features of Silice and can be a good companion in projects. It is specialized to execute code from BRAM, where the code is baked into the BRAM upon synthesis (can be a boot loader later loading from other sources). 

It is easily hackable and would be quite easy to extend to boot from SPI, execute code from a RAM, and connect to various peripherals. The example drives LEDs and an external SPI screen.

The version here runs out of the box on the IceStick ice40 1HK, and can adapted to other boards with minimum effort.

## Features
- implements the RV32I specifications
- runs code compiled with gcc RISC-V (build scripts included)
- executes instructions in 3 cycles, load/store in 4
- less than 1K LUTs
- validates at around 65 Mz on the IceStick
- < 300 lines of commented code (~ 160 without comments)
- 1 bit per cycle shifter
- 32 bits RDCYCLE
- comes with a DooM fire demo ;)

## Running the design

The build is performed in two steps, first compile some code for the processor to run:

From `projects/ice-v` (this directory) run:
```
./compile_c.sh tests/c/test_leds.c
```

Plug your board tp the computer for programming and, from the project folder run:
```
make icestick
```

On an IceStick the LEDs will blink around the center one in a rotating pattern.

You may also simulate the design with:
```
./compile_c.sh tests/c/test_leds_simul.c
make verilator
```
The console will output the LEDs pattern until you press CTRL+C to interrupt
the simulation.
```
LEDs: 00001
LEDs: 00010
LEDs: 00100
LEDs: 01000
LEDs: 00001
...
```

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

<p align="center">
  <img width="400" src="ice-v-doom-fire.png">
</p>


> **Note:** Compling code for the processor requires a RISC-V toolchain. Under Windows, this is included in the binary package from my [fpga-binutils](https://github.com/sylefeb/fpga-binutils) repo. Under macOS and Linux there are precompiled packages, or you may prefer to compile from source. See see [getting
started](https://github.com/sylefeb/Silice/blob/master/GetStarted.md) for more detailed instructions.

&nbsp;<br>

## The Ice-V design: code walkthrough

Now that we have tested the Ice-V let's dive into the code! The [entire design](ice-v.ice) fits in less than 300 lines of Silice code (~160 without comments). 

A Risc-V processor is surprisingly simple! This is also a good opportunity to discover some Silice syntax and features.

The processor is in file [ice-v.ice](ice-v.ice). For the demos, it is included in
a minimalist SOC in file [ice-v-soc.ice](ice-v-soc.ice).

The processor is made of three algorithms:
- `algorithm decoder` is responsible for splitting a 32 bit instruction just read from memory into information used by the rest of the processor.
- `algorithm ALU` is responsible for performing all integer arithmetic: add, sub, shifts, bitwise operators, etc.
- `algorithm rv32i_cpu` is the main processor loop. It fetches instructions from memory, reads registers, setups the decoder and ALU with this data, performs additional memory load/stores as required, and stores results in registers.

Let's start with an overview of the processor loop in `algorithm rv32i_cpu`.

### Processor loop

We will skip everything at the beginning (we'll come back to that when needed) 
and focus on the infinite loop that executes instructions. It has the following structure:

```c
while (1) {

    // 1. - an instruction just became available
    //    - setup register read

++: // wait for registers to be read (1 cycle)

    // 2. - register data is available
    //    - trigger ALU

    while (1) { // decode + ALU while entering the loop (1 cycle)

        // results from decoder and ALU available

        if (dec.load | dec.store) {   

            // 4. - setup load/store RAM address
            //    - enable memory store?

++: // wait for memory transaction (1 cycle)
            
            // 5. - write loaded data to register?
            //    - restore next instruction address
            
            break; // done
            // next instruction read while looping back (1 cycle)
        
        } else {

            // 6. - store result of instruction in register
            //    - setup next instruction address

            if (alu.working == 0) { // ALU done?
                break; // done
                // next instruction read while looping back (1 cycle)
            }
        }
    }
}
```
The loop structure is constructed such that most instructions take three cycles, with load/store requiring an additional cycle. It also allows to wait for the ALU which sometimes needs multiple cycles (shifts proceed one bit per cycle). 
Silice [has precise rules](../../learn-silice/Documentation.md#sec:execflow) on how cycles are used in control flow (while/break/if/else), which allows us to write the loop so that no cycles are wasted.

Let's go through this step by step. The first `while (1)` is the main processor loop. At the start of the iteration (marker `1.` above) an instruction is available from memory, either from the boot address at startup, or from the previous iteration setup. 
We first copy the data read from memory into a local `instr` variable, so that we
are free to do other memory transactions. Given the instruction we also know which registers will be needed, so we immediately setup a read from the registers. In the implementation this is done with this code:
```c
// data is now available
instr       = mem.rdata;
pc          = wide_addr;
// update register immediately
xregsA.addr = Rtype(instr).rs1;
xregsB.addr = Rtype(instr).rs2;
```
The registers are stored in two BRAMs, `xregsA` and `xregsB`, so by setting their
`addr` field, we known that the values of the registers will be in their `rdata`
field at the next clock cycle.

The `Rtype(instr).rs1` syntax is using the bitfield declared at the top of the file:
```c
// bitfield for easier decoding of instructions
bitfield Rtype { uint1 unused1, uint1 sign, uint5 unused2, uint5 rs2, 
                 uint5 rs1,     uint3 op,   uint5 rd,      uint7 opcode}
```
Writing `Rtype(instr).rs1` is the same as `instr[15,5]` (5 bits width from bit 15), but in an 
easier to read/modify format.

After this setup, we wait for one cycle (`++:`) for the register values to be available at the BRAM outputs. Once the register values are available (marker `2.`), the ALU will start refreshing from these updated values. The ALU needs to be told it should trigger its computations at this specific cycle:
```c
alu.trigger = 1;
```
Meanwhile, the decoder which tracks `instr` also started to refresh.

Then we enter a second `while(1)` loop. In many cases we will break out of this second loop after just one cycle, but sometimes the ALU needs to work over multiple cycles, so the loop allows to wait. Entering a loop takes one cycle, so while we enter the loop, data flows through the decoder and ALU, and their outputs are ready when we are in the loop. I'll explain later the timing setup between decoder and ALU.

In the loop we distinguish two cases: either a load/store has to be performed `if (dec.load | dec.store)` or else another instruction is running. Let's first consider the second case (marker `6.`). A non load/store instruction ran through the decoder and ALU.

### Other than load/store

First, we consider writing the instruction result to a register. This is done with the following code:
```c
// store result in register
xregsA.wenable = ~dec.no_rd;
xregsA.addr    =  dec.write_rd;
```
Recall `xregsA` is a BRAM holding register values and its field `addr` indicates which address to read/write to. Its `wenable` field indicates whether we write (1) or read (0). Here, it will be enabled if the decoder output `dec.no_rd` is low. But that seems a bit short? For instance where do we tell *what* to write? This is in fact done earlier in the algorithm, with the following line:
```c
xregsA.wdata   = write_back;
```
This appears in the `always_before` block. This means that at every cycle, before anything else, `xregsA.wdata` is assigned `write_back`, which we explain next. This may be later overwritten in the algorithm, but if not that will be the value of `xregsA.wdata`. This explains why we don't need to set it again when writing the result of the instruction to the register.

But why do that? Why not simply write this code in `6.` alongside the rest? This is for efficiency, both in terms of circuit size and frequency. If the assignment was in `6.` a more complex circuit would be generated to ensure it is only done in this specific state. This would require a more complex multiplexer circuit, and therefore it is best to always blindly set this value. As long as we do not set `xregsA.wenable = 1` nothing gets written anyway. This is a very important aspect of efficient hardware design, and by carefully avoiding uncessary conditions your designs will be made much more efficient. Please also refer to [Silice design guidelines](../../learn-silice/Guidelines.md).

So what is the value of `write_back`? It is defined with the following code:
```c
// what do we write in register? (pc or alu or val, load is handled separately)
int32 write_back <:   do_jump       ? (next_pc<<2) 
                   :  dec.storeAddr ? alu.n[0,$addrW$]
                   :  dec.storeVal  ? dec.val
                   :  alu.r;
```
`write_back <: ...` defines an expression tracker: the read-only variable `write_back` is an alias to the expression given in its definition (a *wire* in Verilog terms).
`write_back` gives the value to write back based on the decoder outputs.
`dec.storeAddr` indicates to write back the address computed by the ALU in `alu.n` (AUIPC). `dec.storeVal` indicates to write back the value `dec.val` from the decoder (LUI or RDCYCLE).
`do_jump` indicates to write back `next_pc<<2` (the shift transform 32-bits instruction pointer into byte addresses). 

`do_jump` is defined earlier as `do_jump <:  dec.jump | (dec.branch & alu.j)`, it combines decoder and ALU
outputs to decide on a jump. `dec.jump` is JAL or JALR and always jumps. `dec.branch`
indicates a conditional branch and the jump is only performed if the ALU output `alu.j`
is set to one -- this is the result of a comparison from the branch condition.

Alright! the register is updated. Back to marker `6.`. Next we set the address of the next instruction to fetch and execute:
```c
// next instruction address
wide_addr      = do_jump ? (alu.n >> 2) : next_pc;
```
This is either the address computed from the ALU in case of a jump/branch
as indicated by (again) `do_jump`, of the value of `next_pc` which is simply `pc + 1`:
the instruction following the current one.

Almost done, but first we have to check whether the ALU is not in a multi-cycle
operations. 
This is why we only break `if (alu.working == 0)`. 
If not, the loop iterates again, waiting for the ALU. 
Note that `6.` will be visited again, so we'll write again to the register. And yes, if the 
ALU is not yet done the write we did before might be an incorrect value. But that is
all fine: the result will be correct at the last iteration, and it costs us nothing
to do these writes. In fact *it costs us less* because not doing them would again 
require more multiplexer circuitry!

After we break, it takes one cycle to go back to the start of the loop. During this
cycle the next instruction is read from `mem` and the result (if any) is written to
the register in `xregsA`. 

> You may have noticed that we wrote the next address in `wide_addr` while the
memory interface is `mem`, so we should have written to `mem.addr`? This is to allow
the SOC to see a wider address bus and perform memory mapping. The address we set
in `wide_addr` is assigned to `mem.addr` in the `always_after` block, that is 
applied at the end of every cycle: `mem.addr = wide_addr[0,11];`. It is also output
from the algorithm to the SOC: `output! uint12 wide_addr(0)`.

### Load/store

That's it for non load/store instructions. Now let us go back to `if (dec.load | dec.store)`
and see how a load/store is handled. Because the Ice-V is specialized for BRAM, we
know all memory transactions take a single cycle. While we'll have to account
for this cycle, this is a big luxury compared to having to wait for an unknown
number of cycles an external memory controller. 

When reaching marker `.4` we first setup the address of the load/store. This address
comes from the ALU:
```c
// memory address from wich to load/store
wide_addr = alu.n >> 2;
```
The sift by two is due to the fact that computed addresses are in bytes, while 
the memory interface addresses are in 32-bits words.

Then, this is either a store or a load. If that is a store, we need to enable
writing to memory. The memory is called `mem` and is a BRAM, given to the CPU: `algorithm rv32i_cpu( bram_port mem, ... )`. The BRAM holds 32 bits words at each address.
To enable writing we set its `wenable` member. However this BRAM has a specificity: 
it allows a write mask. So `wenable` is not a single bit, but four bits, which 
allows to selectively write any of the four bytes at each memory address. 

And we need that! The RISC-V RV32I specification features load/store for bytes,
16-bits and 32-bits words. That means that depending on the instruction (SB/SH/SW)
we need to setup the write mask appropriately. This is done with this code:
```c
// == Store (enabled below if dec.store == 1)
// build write mask depending on SB, SH, SW
mem.wenable = ({4{dec.store}} & { { 2{dec.op[0,2]==2b10} },
                                  dec.op[0,1] | dec.op[1,1], 1b1 
                                }) << alu.n[0,2];
```
That might seem a bit cryptic but what this does is to produces a write mask of the form `4b0001, 4b0010, 4b0100, 4b1000` (SB) or `4b0011, 4b1100` (SH) or `4b1111` (SW) depending on `dec.op[0,2]` (load type) and `alu.n[0,2]` (address lowest bits).
As this may not be a store after all, an AND between the mask and `dec.store` is
applied. The syntax `{4{dec.store}}` means that the bit `dec.store` is replicated
four times to obtain a `uint4`.

Next we wait one cycle for the memory transaction to occur in BRAM with `++:`. If
that was a store we just wrote and we are done when we reach marker `5.` 

If that was a load we just read from memory and now have to store the result 
in the selected register. This is done by this code:
```c
// == Load (enabled below if dec.load == 1)
// commit result
xregsA.wdata   = loaded;
xregsA.wenable = dec.load;
xregsA.addr    = dec.write_rd;
```
Note that here we explicitly set `xregsA.wdata` this time, as the default (`write_back`)
is not what we want to write. `loaded` is set in the `always_before` block as:
```c
// decodes values loaded from memory (used when dec.load == 1)
uint32 aligned <: mem.rdata >> {alu.n[0,2],3b000};
switch ( dec.op[0,2] ) { // LB / LBU, LH / LHU, LW
  case 2b00:{ loaded = {{24{(~dec.op[2,1])&aligned[ 7,1]}},aligned[ 0,8]}; }
  case 2b01:{ loaded = {{16{(~dec.op[2,1])&aligned[15,1]}},aligned[ 0,16]};}
  case 2b10:{ loaded = aligned;   }
  default:  { loaded = {32{1bx}}; } // don't care (does not occur)
}
```
This selects the loaded value depending of whether a byte (LB/LBU), 16-bits (LH/LHU) or 32-bits (LW) were accessed (U indicates unsigned). `mem.rdata` is the value right out of memory, and
it is shifted in `aligned` to be the part selected by the address lowest bits `alu.n[0,2]`.

> Note that `{alu.n[0,2],3b000}` is simply `alu.n[0,2] << 3` (a left shift by three bits is  equivalent to concatenating three 0 bits to the right).

After the load/store is completed we restore the next instruction address, 
so that the processor is ready to proceed with the next iteration after the break:
```c
// restore address to program counter
wide_addr      = next_pc;
// exit the operations loop
break;
```

And that's it! We have seen the entire processor logic. Let's now dive into some
of the other components.

### Register file(s)

We have mentioned that registers are stored in the BRAM `xregsA`. But in fact, two
BRAMS are used: `xregsA` and `xregsB`. They are instantiated at the beginning of the
processor:
```c
bram int32 xregsA[32] = {pad(0)}; bram int32 xregsB[32] = {pad(0)};
```

> `pad(0)` fills the arrays with zeros.

`xregsA` and `xregsB` are always written to together, so they
hold the same values. For this, the design uses an `always_after` block, that is 
always applied at the end of every cycle. These lines replicate what is written
to `xregsA` in `xregsB`:
```c
xregsB.wdata   = xregsA.wdata;   // xregsB is always paired with xregsA
xregsB.wenable = xregsA.wenable; // when writing to registers
```

The reason we use two BRAMs is because we want to read two registers in a single cycle. 
So these two BRAMs always contain the same values, but at a given clock cycle we read from two different addresses:
```c
xregsA.addr = Rtype(instr).rs1;
xregsB.addr = Rtype(instr).rs2;
```

### The decoder

The decoder is a relatively straightforward affair. It starts by decoding all
the possible *immediate* values -- these are constants encoded in the different
types of instructions:
```c
// decode immediates
int32 imm_u  <: {instr[12,20],12b0};
int32 imm_j  <: {{12{instr[31,1]}},instr[12,8],instr[20,1],instr[21,10],1b0};
int32 imm_i  <: {{20{instr[31,1]}},instr[20,12]};
int32 imm_b  <: {{20{instr[31,1]}},instr[7,1],instr[25,6],instr[8,4],1b0};
int32 imm_s  <: {{20{instr[31,1]}},instr[25,7],instr[7,5]};
```
These values are only used when the matching instruction executes. For instance
`imm_i` is used in register-immediate integer operations.

The next part checks the opcode and sets a boolean for every possible instruction:
```c
// decode opcode
uint5 opcode <: instr[ 2, 5];
uint1 AUIPC  <: opcode == 5b00101;  uint1 LUI    <: opcode == 5b01101;
uint1 JAL    <: opcode == 5b11011;  uint1 JALR   <: opcode == 5b11001;
uint1 IntImm <: opcode == 5b00100;  uint1 IntReg <: opcode == 5b01100;
uint1 Cycles <: opcode == 5b11100;  branch       := opcode == 5b11000;
store        := opcode == 5b01000;  load         := opcode == 5b00000;
```
These are of course mutually-exclusive, so only one of these is `1` at a given
cycle.

> You may have noticed there is a difference between e.g. `uint1 IntReg <: opcode == 5b01100`
and `branch := opcode == 5b11000`, where either `<:` or `:=` is used. In the case
of the *wiring operator* `<:` we are defining an expression tracker. In the second
case we are *always assigning* `:=` to an output. Always assigning means that
the output is set to this value first thing every cycle (this is a shortcut
equivalent to a normal assignment `=` in an `always_before` block).

Finally we set the decoder outputs, telling the processor what to do with the instruction.
For instance `write_rd := Rtype(instr).rd` is the index of the destination 
register for the instruction, while `no_rd := branch | store | (Rtype(instr).rd == 5b0)`
indicates whether the write to the register is enabled or not. 

> Note the condition `Rtype(instr).rd == 5b0` in `no_rd`. That is because
register zero, as per the RISC-V spec, should always remain zero.

> The Ice-V as-is has small flaw regarding this prior remark, can you spot it?

### The ALU

The ALU performs all integer computations. It consists of three parts. The 
integer operations such as ADD, SUB, SLLI, SRLI, AND, XOR (output `r`) ; the comparator for conditional 
branches (output `j`) ; the next address adder (output `n`).

Due to the way the data flow is setup we can use a nice trick. The ALU as well
as the comparator select two integers for their operations. The setup of the Ice-V
is such that both can input the same integers, so they can share the same circuits
to perform similar operations. And what is common to `<`,`<=`,`>`,`>=`? They
can all be done with a single subtraction! This trick is implemented as follows:
```c
// trick from femtorv32/swapforth/J1
// allows to do minus and all comparisons with a single adder
int33 a_minus_b <: {1b1,~b} + {1b0,a} + 33b1;
uint1 a_lt_b    <: (a[31,1] ^ b[31,1]) ? a[31,1] : a_minus_b[32,1];
uint1 a_lt_b_u  <: a_minus_b[32,1];
uint1 a_eq_b    <: a_minus_b[0,32] == 0;
```

The integers are selected above based on results from the decoder:
```c
// select ALU and Comparator inputs
int32 a         <: xa;
int32 b         <: dec.regOrImm ? (xb) : dec.aluImm;
```
`a` is always the register, but `b` may be either the register or the immediate.
The choice is made by this line in the decoder:
```c
regOrImm := IntReg  | branch;
```

Similarly, the next address adder selects its two inputs based on the decoder
indications:
```c
// select next address adder inputs
int32 next_addr_a <: dec.pcOrReg ? __signed({20b0,pc[0,10],2b0}) : xa;
int32 next_addr_b <: dec.addrImm;
```
For instance, instructions `AUIPC, JAL` and `branch` will select the program 
counter `pc` for `a` as can be seen in the decoder:
```c
pcOrReg      := AUIPC   | JAL    | branch;         // pc or reg in next addr
```
The next address is then simply the sum of both: `n = next_addr_a + next_addr_b`.

The comparator and most of the ALU are switch cases returning the selected
computation from `dec.op`.
For the comparator:
```c
    // ====================== Comparator for branching
    switch (dec.op) {
      case 3b000: { j =  a_eq_b; } case 3b001: { j = ~a_eq_b;   } // BEQ / BNE
      case 3b100: { j =  a_lt_b; } case 3b110: { j =  a_lt_b_u; } // BLT / BLTU
      case 3b101: { j = ~a_lt_b; } case 3b111: { j = ~a_lt_b_u; } // BGE / BGEU
      default:    { j = 0; }
    }
```
For the integer arithmetic:
```c
// all ALU operations
switch (dec.op) {
  case 3b000: { r = dec.sub ? a_minus_b : a + b; }         // ADD / SUB
  case 3b010: { r = a_lt_b; } case 3b011: { r = a_lt_b_u; }// SLTI / SLTU
  case 3b100: { r = a ^ b;  } case 3b110: { r = a | b;    }// XOR / OR
  case 3b001: { r = shift;  } case 3b101: { r = shift;    }// SLLI/SRLI/SRAI
  case 3b111: { r = a & b;  } // AND
}      
```

However, something is going on for the shifts (SLLI, SRLI, SRAI). Indeed, integer shifts `<<` and `>>`
can be performed in one cycle but at the expense of a large circuit (many LUTs!).
Instead, we want a compact design. So the rest of the code in the ALU describes
a shifter shifting one bit per cycle. Here it is:
```c
  int32 shift(0);
  // shift (one bit per clock)
  shamt   = working ? shamt - 1                    // decrease shift counter
                    : ((dec.aluShift & trigger) // start shifting?
                    ? __unsigned(b[0,5]) : 0);
  if (working) {
    // shift one bit
    shift = dec.op[2,1] ? (dec.negShift ? {r[31,1],r[1,31]} 
                        : {__signed(1b0),r[1,31]}) : {r[0,31],__signed(1b0)};      
  } else {
    // store value to be shifted
    shift = a;
  }
  // are we still working? (shifting)
  working = (shamt != 0);  
```
The idea is that `shift` is the result of shifting `r` by one bit 
each cycle. `r` is updated with `shift` in the ALU switch case: 
`case 3b001: { r = shift; } case 3b101: { r = shift; }`. 
At the beginning, the shifter is not `working` and `shift` is assigned `a`. 
After that, `shift` is `r` shifted by one bit with proper signedness: `shift = dec.op[2,1] ? ...`

`shamt` is the number of bits by which to shift. It starts with the amount read
from the decoder `((dec.aluShift & trigger) ? __unsigned(b[0,5]) : 0)` and then
decreases by one each cycle when `working`. 

> Note how `trigger` is used in the test initializing `shamt` and starting the shifter. This ensures the shifter only triggers at the right cycle, when `alu.trigger` is pulsed to `1` by the processor.

And voilà, our ALU is complete! We are almost done, but one important aspect
remains. How do we make all this work together?

### Plugging the decoder and the ALU together

The decoder and ALU are instantiated within the processor (they are internal
circuitries):
```c
// decoder
decoder dec( instr <:: instr );
// all integer operations (ALU + comparisons + next address)
ALU alu(
  pc          <:: pc,            dec        <: dec,
  xa          <:  xregsA.rdata,  xb         <: xregsB.rdata,    
);
```

The only thing the decoder gets as input is the current instruction `instr`, which does
not change during the processor loop iteration. The ALU gets
the program counter `pc` and the two registers `xregsA.rdata` and `xregsB.rdata`.
Their value is also constant during the processor loop iteration, this is guaranteed
by this code in the `always_before` block of the processor:
```c
// keep reading registers at rs1/rs2 by default
// so that decoder and ALU see them for multiple cycles
xregsA.addr    = Rtype(instr).rs1;
xregsB.addr    = Rtype(instr).rs2;  
```

Both decoder and ALU are active at all times. However, we have seen when studying the 
processor that both operate one after the other within a single cycle:
```c
    while (1) { // decode + ALU occur during the cycle entering the loop
```
One reason to do this is to avoid storing the many outputs of the decoder that
are used by the ALU. This would make the design bigger. A potential drawback will
be a perhaps lower frequency as the ALU operates after the decoder within the same cycle. 
But as it turns out this choice is quite ok.

So how do we plug the decoder and ALU together to achieved this? By carefully selecting how the inputs and outputs are registered between them. 

First, the instruction is wired to the decoder using the `<::` operator.
This means the decoder sees `instr` as it is *before* any change by 
the processor in the cycle. So there is nothing, in terms of circuitry, between
the value of `instr` and what the decoder does from it in the cycle.

During the cycle, the data flows through the decoder and reaches
its outputs. The decoder outputs are all declared as `output!`. The exclamation
mark indicates that the outputs are not registered: they are directly the output
of the decoder circuit. Then, when the ALU is wired to the decoder, the ALU sees
on its inputs what the decoder did during the same cycle. Any circuitry added 
by the ALU comes *after* the circuitry of the decoder.

In contrast, the ALU outputs are all `output`, without the `!`. 
These outputs are registered: so the processor will see the result only 
at the start of the next cycle, but without any circuitry in between.

The the data flow from the decoder circuit to the ALU circuit and stops there.
One the next cycle the processor sees the new values on the output of the ALU.

The maximum frequency is likely determined by the longest path through decoder and ALU,
which is somewhat complex. Nextpnr critical path analysis indeed confirms that.

And that's it! There are a few more details I'll likely add below in the future,
but we have seen 90% of the processor operations!

> For all details on the (important!) topic of algorithm bindings and timings [please refer to the dedicated page](../../learn-silice/AlgoInOuts).

> Some other designs, such as the [fire-v](../fire-v/doc/fire-v.md), choose
to put decoder and ALU in separate cycles to obtain a higher frequency. The Ice-V
can also be modified to experiment with such an approach, feel free to experiment!

## Other implementation details

To be written ...

## Links

This implementation benefited from reading through many other projects (see also comments
in source):

* Ice-V's best friend: FemtoRV https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV
* PicoRV  https://github.com/cliffordwolf/picorv32
* Stackoverflow post on CPU design (see answer) https://stackoverflow.com/questions/51592244/implementation-of-simple-microprocessor-using-verilog

A few other great RISC-V projects (there are many! happy to add links, let me know)

* The smallest processor in the world: [SERV](https://github.com/olofk/serv)
* [vexriscv](https://github.com/SpinalHDL/VexRiscv)
* [neorv32](https://github.com/stnolting/neorv32)

Toolchain links:

* RISC-V toolchain https://github.com/riscv/riscv-gnu-toolchain
* Pre-compiled riscv-toolchain for Linux https://matthieu-moy.fr/spip/?Pre-compiled-RISC-V-GNU-toolchain-and-spike&lang=en
* Homebrew RISC-V toolchain for macOS https://github.com/riscv/homebrew-riscv
