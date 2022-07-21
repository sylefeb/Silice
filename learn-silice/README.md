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

> This is not only about the routes, the LUTs can be configured as *asynchronous* in which case they constantly update their outputs when the inputs change. In such case, the delay is the sum of routes and LUTs to traverse. This is very typical: a design contains many synchronous (flip-flop) and asynchronous (*combinational*) gates.

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

Let's do a first design! This is the hello world of FPGA. Most boards have LEDs connected to the FPGA, if only for debugging. So the hello world consists in making these LEDs blink. Here's one possible Silice version:

<!-- MARKDOWN-AUTO-DOCS:START (CODE:src=./tutorial/step1.si&syntax=c) -->
<!-- The below code snippet is automatically added from ./tutorial/step1.si -->
```c
unit main(output uint8 leds)
//               ^^^^^ assumes 8 LEDs on board, will work in any case
{
  uint24 counter(0);
  //  ^^ 24 bits ^
  //             | initialized at configuration time
  always {
    leds    = counter[0,8];
    //                ^^^ from bit 0, take 8 bits
    // (simulation only) display leds as a vector of bits
    __display("leds:%b",leds);
    // increment the counter
    counter = counter + 1;
  }
}
```
<!-- MARKDOWN-AUTO-DOCS:END -->

To run it in simulation, enter the [`tutorial`](./tutorial) directory and run `make verilator file=step1.si`. Hit CTRL-C to stop the output.

You'll see this (looping forever):
```
leds:00000000
leds:00000001
leds:00000010
leds:00000011
leds:00000100
leds:00000101
leds:00000110
...
```

On real hardware the LEDs will blink with the corresponding pattern. That will be too fast to see (it will appear as if all LEDs are on, with slightly different brightness), we'll fix that in a minute.

Let's first walk through this example:
- `unit main( )`: This defines the main circuit of the design. All Silice designs are meant to have a main circuit, which is instantiated automatically.
- `output uint8 leds`: This means our circuit outputs an 8 bits signal called `leds`. This directly corresponds to eight pins going outside of the FPGA and driving actual LEDs on the board.

> How does Silice know there are LEDs on the board? The pin configuration is defined in the [board frameworks](../frameworks/boards/README.md), and we tell which pins we use [in the Makefile](tutorial/Makefile). Here the set of pins is called `basic` (hence `-p basic` in the Makefile). Many boards also have `buttons`, `uart`, etc.

- `uint24 counter(0)`: This creates a `counter` variable which is unsigned and is 24 bits wide. Because we are describing hardware we could make it any width, e.g. `uint3`, `uint13`. Variables can also be signed (e.g. `int3`). Indicating `(0)` means that the counter is initialized to `0` upon FPGA configuration.

- `always { ... }`: The always block describes operations performed at every cycle. This implies that whatever is inside has to be applicable in a single cycle: the always block is a *one-cycle* block.

- `leds = counter[0,8]`: We assign to `leds` the 8 less significant bits of `counter`. `0` means from bit `0` and `8` is the width we take. We could have used `counter[16,8]` to take the eight most significant bits.

- `__display(...)` prints the `leds` variable in binary format (`%b`). *This is only active in simulation* and is ignored otherwise. Using `__display` is very helpful to check some variables during simulation.

> Another, more powerful way to simulate is to output a full trace (wave) of the simulated design which records the status of all variables, every clock cycle, for the entire simulation. But that's a topic for later!

- `counter = counter + 1;`: We increment the counter every clock cycle.

And this is it, we already have seen quite a few concepts!

> **Exercise**: change `counter[0,8]` to slow down the LEDs pattern.

### Step 2: a second unit

Of course your design may contain other units beyond main, and main can *instantiate* other units. Indeed, a unit describes a circuit blueprint, but it has to be explicitly instantiated before being used (only main is automatically instantiated).

Here is an example where a second unit generates a pattern that is then applied to the LEDs:

<!-- MARKDOWN-AUTO-DOCS:START (CODE:src=./tutorial/step2.si&syntax=c) -->
<!-- The below code snippet is automatically added from ./tutorial/step2.si -->
```c
// create a unit producing a 'rotating' bit pattern
unit rotate(output uint8 o)
{
  uint8 bits(8b1);
  always {
    o    = bits;
    bits = {bits[0,1],bits[1,7]};
  }
}
// main unit
unit main(output uint8 leds)
{
  rotate _(o :> leds); // instantiate the unit
  //         ^^ bind leds to the output
  always {
    __display("leds:%b",leds); // print leds
  }
}
```
<!-- MARKDOWN-AUTO-DOCS:END -->

Let's walk through this example:
- `unit rotate(output uint8 o)` declares a unit which outputs an 8 bit wide value, named `o`.
- `uint8 bits(8b1)` is an 8 bit internal variable initialized at configuration time with `8b1` which is a fancy way to say `1`, showing explicitly sized constants and binary basis (`b` for binary, `h` for hex and `d` for decimal). While unimportant in this case, sizing constants is good practice (and critical in some cases).
- `always{ ... }` means we are doing these operations at every cycle, always and forever.
- `o = bits;` assigns the output.
- `bits = {bits[0,1],bits[1,7]};` creates the rotating pattern. Here's how: `bits[0,1]` is the lowest bit, `bits[1,7]` are the seven other bits, and `{..,..,..}` concatenates into a different bit vectors. So in effect this moves bit `0` to bit `7` and shifts all other bits right. Handy! (All bit operators are directly inherited from Verilog).

Now let's move to main:
- `rotate _(o :> leds);` *instantiates* the unit rotate. In this case the instantiation is anonymous ; `_` could have been an identifier, but means *don't care* here because we never need to refer to the instance. That is because we directly *bind* the output `o` to `leds` using the `:>` operator. This way, `leds` tracks the value of the output `o` from the instance.

> Of course we can also bind inputs, but we need to introduce another concept before that.

- `__display` is printing leds in simulation.

What is the result of this exactly? Let's run in simulation: enter the [`tutorial`](./tutorial) directory and run `make verilator file=step2.si`. Hit CTRL-C to stop the output.

We get this:
```
leds:00010000
leds:00001000
leds:00000100
leds:00000010
leds:00000001
leds:10000000
leds:01000000
leds:00100000
```

Indeed, that's a rotating bit pattern!

Alright, we again saw some very important concepts: unit instantiation, binding and some bit manipulation. Now we need to explain something excruciatingly important: registered outputs and latencies.

## Step 3: the clock, the cycles, and the registered outputs

Designing hardware often means carefully orchestrating what happens at every cycle. Therefore, it is important to understand how information flows through your design, and in particular in between parent and instantiated units.

So let's modify our example from step 2 to report the cycle at which every operation is performed:

<!-- MARKDOWN-AUTO-DOCS:START (CODE:src=./tutorial/step3.si&syntax=c) -->
<!-- The below code snippet is automatically added from ./tutorial/step3.si -->
```c
unit rotate(output! uint8 o)
{
  uint32 cycle(0); // count cycles
  uint8 bits(8b1);
  always {
    o    = bits;
    __display("[%d] o :%b",cycle,o); // print o at cycle
    bits = {bits[0,1],bits[1,7]};
    cycle = cycle + 1; // increment cycle counter
  }
}
// main unit
unit main(output! uint8 leds)
{
  uint32 cycle(0); // count cycles
  rotate _(o :> leds);
  always {
    __display("[%d] leds:%b",cycle,leds); // print leds at cycle
    cycle = cycle + 1; // increment cycle counter
  }
}
```
<!-- MARKDOWN-AUTO-DOCS:END -->

Change log from step 2:
- We add a 32-bits `cycle` variable in both unit, incremented at the end
of the always block `cycle = cycle + 1`. These will be perfectly in synch
since the entire design starts precisely on the same initial clock cycle.
- We print the value of `cycle` alongside the value of `o` in unit `rotate`
and alongside the value of `leds` in `main`.

Here is the output for three cycles:
```
[     53057] o   :10000000
[     53057] leds:00000001
[     53058] o   :01000000
[     53058] leds:10000000
[     53059] o   :00100000
[     53059] leds:01000000
```
Look very carefully. See how the value of `o` is in advance by one cycle
compared to the value of `leds`? That's because by default unit outputs are
*registered*. This means that whatever change occurs in the instantiated unit,
the parent will only see the change *at the next cycle*.

Why would we do that? Remember [the introduction](#fpga-hardware-design-101) and
how we talked about delay in propagating changes through the routes and
asynchronous gates? If nothing was ever registered, by instantiating units we
would end up creating very long critical paths, resulting in slow designs. So
typically we want to register outputs, or inputs, or even both. And sometimes
none of them. All of that is possible in Silice. For instance, let's switch
to an immediate output using the `output!` syntax on our outputs:
```c
unit rotate(output! uint8 o) ...
//                ^ note the exclamation mark
```

Now the output is:
```
[     53057] o   :10000000
[     53057] leds:10000000
[     53058] o   :01000000
[     53058] leds:01000000
[     53059] o   :00100000
[     53059] leds:00100000
```
See how `leds` now immediately reflects `o`? That's because there is no register
in the path anymore.

Alright, we've seen how to bind outputs and how to register them.
How about inputs?

## Step 5: inputs
