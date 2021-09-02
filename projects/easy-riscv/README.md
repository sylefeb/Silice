# RISC-V / Silice integration demo

> **Note:** This feature is currently being developed. This is an early preview and things are subject to change. Please let me know what you think, feedback is most welcome!

## TL;DR

Include RISC-V processors and their firmware in a few lines of code in your Silice designs!

This example is a complete RISC-V blinky, and it is crazy short:
```c
riscv cpu_blinky(output uint32 leds) <mem=256> = compile({
  // ========= firmware C-code below
  void main() { 
    int i = 0;
    while (1) { // until the end of times
      leds(i);  // output to leds
      for (int w = 0 ; w < 100000 ; ++w) { asm volatile ("nop;"); } // wait
      ++i; // next
    }
  }
  // ========= end of firmware C-code
})

algorithm main(output uint8 leds)
{
  cpu_blinky cpu0;   // instantiates our CPU as defined above
  leds := cpu0.leds; // always set the hardware LEDs to the CPU output
}
```

This compiles to hardware and runs right out of the box. *Nothing else is required*.

## The full story

Silice works great to combine RISC-V softcores and custom co-processors.
For some examples see for instance the [fire-v graphics demos](../fire-v/README.md), [voxel terrain demo](../terrain/README.md) and the [ice-v](../ice-v/README.md).

The reason it works so well is because Silice makes it easy to reuse components and combine them. However, including a RISC-V processor in a design requires a few other things, such as external C-code compilation and embedding of the result into BRAM. None of that is hard, but doing it over and over can become tedious.

But worry not, Silice RISC-V integration makes this process entirely trivial! As you can see in the above code and the [commented source code](main.ice) of this project, you can now declare a RISC-V processor *and* its C-language firmware *directly into your Silice source code*. Silice takes care fo everything else! 

> **Note:** The firmware C code does not have to be in the Silice source code, it can also be included as an external file to avoid confusion.

In addition inputs and outputs can be specified in a straightforward manner. See `output uint32 leds` in the `cpu_blinky` declaration above? This automatically generates the C-function `void leds(unsigned int)` that the firmware uses to set `leds` in the hardware design. The same is possible for inputs; for instance declaring `input int32 a` would similarly create a function `int a()` that would allow the CPU to read the value of `a` from the hardware.

## Testing

Plug your favorite board, open a command line in this folder and type `make <board name>`.

## RISC-V cores

Currently Silice uses the [ice-v](../ice-v/README.md) RISC-V [core](../ice-v/CPUs/ice-v.ice) (small and works great for micro-controller style CPUs). 

The plan is of course to make this configurable! Many options are planned, from using other cores to enabling access to external memory. So stay tuned!

