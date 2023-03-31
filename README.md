# Silice
*A language for hardcoding algorithms into FPGA hardware*

---
**Quick links:**
- To set up Silice, see the [getting started](GetStarted.md) guide.
- To see what can be done with Silice, check out the [example projects](projects/README.md) (all are available in this repo).
- To start designing hardware, see [learn Silice](learn-silice/README.md).
- Watch the introduction video on [programming FPGAs with Silice](https://www.youtube.com/watch?v=_OhxEY72qxI) (youtube).
- Watch the [video on the IceV-dual](https://www.youtube.com/watch?v=fr4Dst1fQrk&t=6647s), a dual core RV32I riscv processor [included in this repo](projects/ice-v/IceVDual.md).
- Browse the slides and watch the video on the [doomchip-onice](https://www.antexel.com/doomchip_onice_rc3/), a GPU for Doom 1993 written in Silice.
- Browse through the [reference documentation](learn-silice/Documentation.md).
- Feel free to ask questions about the language syntax in this [github issue](https://github.com/sylefeb/Silice/issues/108).
- Refer to the [optimization guidelines](learn-silice/Guidelines.md) for fine tuning your Silice designs.
- Read how to [add a new board](frameworks/boards/README.md) in the Silice build system.
- See details [about the license](LICENSE.md).

**Important:** Silice is under active development [read more](#project-status-alpha-release).

**Important:** To enjoy the latest features please use the *draft* branch. [Read more about development branches](#development-branches).

**Important:** Something no longer compiles? The [change log](ChangeLog.md)
documents (rare) breaking changes and how to recover from them.

---

## What is Silice?

Silice is an easy-to-learn, powerful hardware description language, that allows
both to prototype ideas quickly and then refine designs to be compact and
efficient.

Silice achieves this by offering a few, carefully designed high level design
primitives atop a low level description language. In particular, Silice allows
to write and combine algorithms, pipelines and per-cycle logic in a coherent,
unified way. It features a powerful instantiation-time pre-processor,
making it easy to describe parametric designs.

Silice offers a ready-to-go design environment, supporting many FPGA boards, both
open-source and proprietary. It natively supports simulation and formal
verification.

Silice syntax is simple, explicit and easy to read, and should feel familiar
to C programmers and Verilog designers alike.

Silice comes with [a ton of examples](projects/README.md), from a simple blinky
to SDRAM controllers, [tiny RISCV CPUs](projects/ice-v/README.md)
(dual core RV32I in less than 120 lines!)
and [a GPU](projects/tinygpus/README.md) capable of rendering Doom and Quake
levels on low cost, low power FPGAs. Examples include full hardware re-implementations
of the render loops of [Comanche 1992](projects/terrain/README.md)
and [Doom 1993](projects/doomchip/README.md).
Many [basic components](projects/common/) are available in the repository to get
you started on your designs (VGA, HDMI, OLED, UART, SDRAM, SDCARD and
SPIflash controllers).

The build system already supports many [popular boards](frameworks/boards/boards.json)
such as the IceBreaker, de10-nano, ULX3S, Fomu and IceStick.
Silice works great with the
open-source FPGA toolchain (yosys/nextpnr/icestorm), see
our [Ice40 and ECP5 examples](projects/README.md).

You do not need an FPGA to start with Silice: designs and their outputs
(e.g. VGA signals) can be simulated and visualized.

While I developed Silice for my own needs, I hope you'll find it useful for
your projects!

### Tutorial:

Checkout the [Silice mega-tutorial](learn-silice/README.md) (still being written).

### A first example:
*(see also the full [blinky tutorial](learn-silice/blinky/README.md))*

##### Code:
```c
1  algorithm main(output uint8 led) {
2    uint28 counter = 0;      // a 28 bits unsigned integer
3    led := counter[20,8];    // LEDs updated every clock with the 8 most significant bits
4    while (1) {              // forever
5      counter = counter + 1; // increment counter
6    }
7  }
```

##### Compile:
```
cd projects
cd blinky
make mojov3
```

##### Enjoy!

![First example in action on a Mojo v3](learn-silice/figures/first_example.gif)

##### Explanations:

Line 1 is the entry point of any Silice hardware: the main algorithm. Line 2 we define
a 28-bit unsigned int, initialized to 0. Initializers are mandatory and are always constants.
Line 3 we request that the output led tracks the eight most significant bits of the counter variable.
The syntax [20,8] means 8 bits wide starting from bit 20. The assignment to led
uses the := operator which is an *always* assignment: led is now automatically
updated with counter after each rising clock. Such assignments have to appear
at the top of an algorithm, right before any other instruction.

Finally, lines 4-6 define the infinite loop that increments the counter. Of course the
28 bit counter will ultimately overflow and go back to 0, hence the cyclic LED light pattern.
In this case, the loop takes exactly one cycle to execute: we have one increment per cycle
at 50 MHz (the clock frequency of the Mojo v3).

We then compile with silice. The -f parameter indicates which framework to use: this is an
FPGA platform dependent wrapper code. Here we are using the Mojo framework with LEDs only.
Several other frameworks are provided, and it is easy to write your own.

The -o parameter indicates where to write the Verilog output. In this example we overwrite
the main file of a pre-existing project, which is then compiled using Xilinx ISE toolchain.
Fear not, we also have examples working with yosys, nextpnr and [project icestorm](http://www.clifford.at/icestorm/)!

### Cycles and control flow:

Here is another small example outlining a core principle of Silice:

##### Code:
```c
1 algorithm main() {
2    brom int12 sintbl[4096] = {...}
3    ...
4    while (1) { // render loop
5      // get cos/sin view
6      sintbl.addr = (viewangle) & 4095;
7  ++:
8      sinview     = sintbl.rdata;
9      sintbl.addr = (viewangle + 1024) & 4095;
10 ++:
11     cosview     = sintbl.rdata;
12     ...
```
##### Explanations:

This code is storing a sine table in a block ROM and accesses it to obtain a cosine and sine for the current view angle.
Note the use of the **++:** *step* operator in lines 7 and 10. This explicitly splits the exectution flow and introduces a one cycle delay, here waiting for the brom to output its result in field *rdata* for the select address in *addr*.
Anything in between is considered combinational; for instance lines 8 and 9 are evaluated in parallel on hardware, as they
each produce two pieces of independent circuitry.

#### Other examples with detailed explanations

This repo contains many [example projects](projects/), some including detailed code walkthrough:
- [HDMI test framework](projects/hdmi_test/)
- [streaming audio from sdcard](projects/audio_sdcard_streamer/)
- [Pipelined sort](projects/pipeline_sort/)

## Getting started with Silice

See the [getting started](GetStarted.md) guide. Silice runs great on Windows, Linux, and macOS!
To start writing code, see [writing your first design](FirstDesign.md).
To see what can be done with Silice, check out our [example projects](projects/README.md) (all are available in this repo).

## Project status: in development

Silice can already be used to create non trivial designs, from a tiny Risc-V processor to an entire game render loop (visit the [examples](projects/README.md) page).

However Silice is under active development. I decided to open the repo so everyone can join in the fun, but it is not yet stable and feature complete. Some documentation is lacking, some examples are outdated or far from polished, and known issues do exist (head out to the [Issues](https://github.com/sylefeb/Silice/issues) page).

I am extremely attached to backward compatibility, and work very hard to avoid
breaking changes. Some adjustments are however sometimes necessary. If something
no longer works please check the [change log](ChangeLog.md), and feel free to
reach out for help.

I hope you'll enjoy diving into Silice, and that you will find it useful.
Please let me know your thoughts: comments and contributions are welcome!

## Development branches

- **master** is the latest, most stable version
- **wip** is where new features are being implemented, less stable but reasonnable
- **draft** is heavy experimental work in progress, likely unstable, may not compile

## Directory structure
- **learn-silice** contains documentation and tutorials
- **projects** contains many demo projects ([see README therein](projects/README.md)) as well as build scripts for several boards
- **bin** contains the Silice binaries after compiling using the ```compile_silice_*.sh``` script
- **frameworks** contains the frameworks for various boards and setups
- **tools** contains tools useful for Silice development, either source or binary form (to be installed, see [getting started](GetStarted.md))
- **src** contains Silice core source code
- **antlr** contains Silice grammar and parsing related source code
- **tests** contains test scripts for Silice development

## License

GPLv3 (Silice compiler) and MIT (examples and glue code), but please refer to the [dedicated page](LICENSE.md).

## Credits

- Silice logo by Pierre-Alexandre Hugron ([Twitter](https://www.twitter.com/@HugronPa))
