# RISC-V / Silice integration demo

> **Note:** This feature is still being refined. Please let me know what you think, feedback is most welcome!

## TL;DR

Include RISC-V processors and their firmware in a few lines of code in your Silice designs!

This example is a complete RISC-V blinky (the CPU counts and outputs the counter
onto the LEDs):
```c
riscv cpu_blinky(output uint32 leds) <mem=256> {
  // ========= start of firmware C-code
  void main() {
    int i = 0;
    while (1) { // until the end of times
      leds(i);  // output to leds
      for (int w = 0 ; w < 100000 ; ++w) { asm volatile ("nop;"); } // wait
      ++i; // next
    }
  }
  // ========= end of firmware C-code
}

algorithm main(output uint8 leds)
{
  cpu_blinky cpu0;   // instantiates our CPU as defined above
  leds := cpu0.leds; // always set the hardware LEDs to the CPU output
}
```

This compiles to hardware and runs right out of the box. *Nothing else is required*.

## The full story

Silice works great to combine RISC-V softcores and custom co-processors.
For some examples see for instance the [fire-v graphics demos](../fire-v/README.md), [voxel terrain demo](../terrain/README.md) and the [ice-v demos](../ice-v/README.md).

The reason it works so well is because Silice makes it easy to reuse components and combine them. However, including a RISC-V processor in a design requires a few other things, such as external C-code compilation and embedding of the result into BRAM. None of that is hard, but doing it over and over can become tedious.

But worry not, Silice RISC-V integration makes this process entirely trivial! As you can see in the above example and this [project source code](main.ice),  you can now declare a RISC-V processor *and* its C-language firmware *directly into your Silice source code*. Silice takes care fo everything else!

> **Note:** The firmware C code does not have to be inlined in the Silice source code, it can also be included as an external file.

In addition inputs and outputs can be specified in a straightforward manner. See `output uint32 leds` in the `cpu_blinky` declaration above? This automatically generates the C-function `void leds(unsigned int)` that the firmware uses to set `leds` in the hardware design. The same is possible for inputs; for instance declaring `input int32 a` would similarly create a function `int a()` that would allow the CPU to read the value of `a` from the hardware. You can also request a special output that will pulse whenever a given output is written (or a given input is read). See the [on_accessed example](./on_accessed/main.ice) for more details.

The [project source code](main.ice) shows of a few additional possibilities regarding interactions with the pre-processor; see comments therein. More elaborate examples will follow, stay tuned!

## Testing

Plug your favorite board, open a command line in this folder and type `make <board name>`.

There are subdirectories containing more advanced examples:
- Selecting the ice-v-dual CPU in [select_core](select_core/with_ice-v-dual.ice)
- Adding special outputs telling when an input/output is accessed in [on_accessed](main.ice)
- Driving an OLED/LCD small screen from the CPU in [oled](oled/main.ice)

The repo contains larger projects using RISCV integration, such as the [Doom fire](../kbfcrabe/README.md).

## RISC-V cores

Currently Silice uses the [ice-v](../ice-v/README.md) RISC-V core (small and simple). The plan is of course to make this configurable. Many options are planned, from using other cores to enabling access to external memory.

## Behind the scene

Have a look in the [frameworks/libraries/riscv](../../frameworks/libraries/riscv) folder. There you will find the SOC template as well as the Lua pre-processor
script calling *gcc*. Silice produces the RISC-V instructions from the C
firmware code and embeds the machine code into the SOC, calling itself to produce
the Verilog code of the softcore. This code is then added to the design being
compiled in the first place.
