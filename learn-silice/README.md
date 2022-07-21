# Learn FPGA programming with Silice

> This tutorial covers the basics with many code snippets. It is a hands on approach to learning Silice.

Quick pointers:
- Silice [reference documentation](Documentation.md).
- [Advanced topics](Advanced.md) page.
- Have a question about the language syntax? [Ask it here](https://github.com/sylefeb/Silice/issues/108).

## Which FPGA to choose?

> You don't really need an FPGA to start learning Silice, because everything can be simulated. However, it is more fun to run things on actual hardware!

There are many great options, and I mention below those which are best supported by Silice's framework. However this is a continuously expanding list! Whichever board you choose, *I strongly recommend a board with an FPGA well supported by the open source tool chain*. These are typically Lattice FPGAs: ice40 HX1K to HX8K, UP5K and the ECP5 family. Other FPGAs start being supported too (Gowin, Xilinx Artix-7) but setup may be a bit more difficult. However things are evolving quickly, the community is working hard!

As a beginner, the [IceStick](https://www.latticesemi.com/icestick) and [IceBreaker](https://1bitsquared.com/products/icebreaker) are great first options, with a preference to the *ICeBreaker* for more flexibility.

The *IceStick* is small and inexpensive (1280 LUTs) but can still host many cool projects (checkout Silice [tiny Ice-V RISC-V processors](../projects/ice-v) and accompanying demos).

The *IceBreaker* is ~5 times larger (5280 LUTs) and offers a lot more connectivity, with many useful PMODs (modules that plug into the board connectors), for instance for VGA output. More generally, all boards featuring the similar UP5K ice40 FPGA and PMODs are great choices.

The [ULX3S](https://radiona.org/ulx3s/) is great for both simple and advanced projects. It features a more powerful ECP5 FPGA, and plenty of peripherals and connectivity.

## FPGA hardware design 101

The most important thing to remember, as you enter these tutorials, is that the code we write describes a *hardware design*. This is <ins>not</ins> code that will be *executed*. This is code that gets turned into an actual circuitry, composed of FPGA blocks configured and connected together to produce the circuit we described. This is illustrated below, where each block is a configurable FPGA lookup table (LUT) and blue connections are configurable routes between these blocks. In this example all blocks are *synchronous*: they only update their outputs from the inputs when the clock raises. Such blocks are implementing so-called *flip-flops*.

<p align="center">
  <img src="figures/gates.png">
</p>

> If you want to more explanations about this, please refer my talk about the Doomchip-onice ([slide](https://www.antexel.com/doomchip_onice_rc3/#/13),[video](https://youtu.be/2ZAIIDXoBis?t=483)). Also checkout my [FPGA gate simulator page](https://github.com/sylefeb/silixel).

From the illustration we can guess a few things:
- The circuit uses FPGA blocks (or LUTs for Lookup Up Tables), so there is a notion of how big it will become. Complex designs may not fit on smaller FPGAs. This *resource usage* is fun (and often important) to optimize, an activity often called *LUT golfing*.
- The routes can have different lengths. Because this is a circuit, and a configurable one at that, the signal takes actual time to propagate along the routes. This leads to delays. For instance, say that our longest route needs $50$ *nanoseconds* to propagate the signal. Our circuit will not be able to run faster than $\frac{1000}{50} = 20$ MHz. This longest route is called the *critical path*. [Nextpnr](https://github.com/YosysHQ/nextpnr) (the tool that maps the circuit to the FPGA) will tell us this max frequency, or *fmax*.

> This is not only about the routes, the LUTs can be configured as *asynchronous* in which case they constantly update their outputs when the inputs change. In such case, the delay is the sum of routes and LUTs to traverse.

Finally, something to remember, especially if you have a background in programming on CPU: *There is no concept of "not doing something"*. *Everything* you describe becomes a circuit and takes space on the FPGA. On CPU we tend to write thing like:
```c
  if (condition) {
    do_something(); // could be always done, skip for faster exec
  }
```
The intent here is to skip the execution of `do_something()` when `condition` is false. However, if `do_something` can be always done anyway, on an FPGA doing the test will be *less efficient*: it will add LUTs and route delays *in addition* to the `do_something` circuit.

It takes time and practice to get used to that, but it is also a fun mindset, and a refreshing experience.

## Tutorial, step by step

To run these examples, enter the [`tutorial`](./tutorial) directory, and run (here for step1):
```
make verilator file=step1.si
```
If you have an FPGA you can replace `verilator` by the name of your board. Plug the board first and it will be programmed automatically in most cases.

> Simulated designs run forever, hit CTRL-C to stop them.

### Step 1: a simple blinker

Let's do a first design! This is the hello world of FPGA. Most boards have LEDs connected to the FPGA, if only for debugging. So the hello world consists in making these LEDs blink.

In Silice we'll do:
<!-- MARKDOWN-AUTO-DOCS:START (CODE:src=./tutorial/step1.si&syntax=c) -->
<!-- The below code snippet is automatically added from ./tutorial/step1.si -->
```si
unit main(output uint8 leds)
//               ^^^^^ assumes 8 LEDs on board, will work in any case
{
  uint24 counter(0);
  //  ^^ 24 bits ^
  //             | initialized at configuration time
  always {
    leds    = counter[16,8];
    //                ^^^^^ from bit 16, take 8 bits
    // (simulation only) display leds as a vector of bits
    __display("leds:%b",leds);
    // increment the counter
    counter = counter + 1;
  }
}
```
<!-- MARKDOWN-AUTO-DOCS:END -->
