## Blinky tutorial

This tutorial is a gentle introduction to Silice. It shows how to setup a project, as well as some basics of the language. We will start from one implementation of *blinky* (the *hello world* of FPGAs, where we make LEDs blink), and modify it to introduce some Silice features and have fun!

The project is designed for the IceStick and IceBreaker, but really it will compile for any supported board. It's just that it assumes 5 LEDs are present on the board.

### *Project structure*

Each Silice project is a directory, with a [Makefile](Makefile). 

To build the project in this tutorial open a command line in this directory and run:

```
make file=blinky1.ice icebreaker
```

This tells the makefile to call the Silice build system on file `blinky1.ice` (each version of blinky will be a separate file), and to compile for the `icebreaker`. If you have a different board, replace the last parameter by its name: `icestick`, `ulx3s`, etc. Supported boards are [listed here](../../frameworks/boards/boards.json).

### *A first blinky*

Our first blinky (spoiler: *it does not blink!*) is in [blinky0.ice](blinky0.ice). Here is the source code:

```c
algorithm main(output uint5 leds)
{
  leds = 5b11110;
}
```

A standard Silice project always implements a `main` algorithm. This is the top level algorithm, that always runs on the design. 

The `main` algorithm connects to the outer world through its inputs and outputs. Here we are driving LEDs, five of them, hence the `output uint5 leds` in the algorithm declaration. 

This output is actually expected by the build system so the algorithm has to define it. But how does the build system know we want to use the LEDs? This is actually in the [Makefile](Makefile), when we give the `-p basic` parameter. `basic` tells we want the basic peripherals, which are the LEDs. This could be a list, for instance `-p basic,buttons` if we also want the on-board buttons. To check what is available for a board, refer to its `board.json`, for instance here is the one for the IceBreaker: [frameworks/boards/icebreaker/board.json](../../frameworks/boards/icebreaker/board.json), see section *variants/pins* and the various named sets.

Alright, now we know why our `main` is expected to have a `leds` output. Because we have five LEDs, the output is of type `uint5`. This means *unsigned integer of bit width 5*. Silice has only two basic types, `uint` (unsigned) and `int` (signed), and these are *always* followed by a bit width, e.g. `int32` for a 32 bits signed int. On an FPGA we are welcome to use any bit-width such as `uint9` or `uint73`. Of course, the larger the heavier in terms of FPGA resources, but let's put that aside for now.

So what can we do with `leds`? Each bit of `leds` controls one LED. So by giving a value to `leds`, we set its bits and directly control which LEDs are on or off. A zero turns off the LED, a one lights it up.

`leds = 5b11110;` does exactly that. This line is actually the same as `leds = 5d30` or `leds = 5h1E` (try it!). That is because `5b11110`, `5d30` and `5h1E` all describe the same 5 bits wide constant (hence the leading 5) either in binary (*b*), decimal (*d*) or hexadecimal (*h*). We could also have simply written `leds = 30`, that is fine here, but it is generally better to indicate the size of the constants and avoid bad surprises (see [arithmetic rules and constant sizes](../ExprBitWidth.md)).

So when we run this design, the only thing that happens is that we lit all LEDs but one (red LED0, in the center).

We could have written this more concisely. In Silice, outputs can have default value, so we can simply write:

```c
algorithm main(output uint5 leds = 5b11110)
{

}
```

### *A second blinky, that blinks (!)*

Our first blinky is a bit too static! Let's make a second version:

```c
algorithm main(output uint5 leds)
{
  uint26 cnt = 0;
  
  while (1) {
    leds = cnt[21,5];
    cnt  = cnt + 1;
  }
}
```

The big addition here is `cnt`. This is an unsigned integer of 26 bits that we declare with `uint26 cnt = 0`. Note that in Silice, all variables always get a value upon declaration (but this value can be *`uninitialized`* -- just to make sure this is spelled out and not an omission).

We then enter an infinite loop: `while (1) { ... }`. Yes, that is perfectly fine! We are designing hardware, and it will run for as long as there is power. 

Two things happen in this loop. We can see that `cnt` is incremented with `cnt  = cnt + 1`. But then, just before, we have this interesting syntax: `leds = cnt[21,5]`. Since we are describing hardware, there will be a lot of manipulation of bits (just as with *Verilog / VHDL*). What this line means is that `leds` gets assigned 5 bits of `cnt` from bit 21 ; that is `leds` gets bits 21, 22, 23, 24 and 25 of `cnt` (the first bit is bit 0). So the syntax `[21,5]` means "extract 5 bits starting from bit 21".

This algorithm is fine as is, but we can make two variants to illustrate some Silice features. First, our intent here is to always assign `cnt[21,5]` to `leds`, and this can be written as:

```c
algorithm main(output uint5 leds)
{
  uint26 cnt = 0;
  
  leds := cnt[21,5];

  while (1) {
    cnt  = cnt + 1;
  }
}
```
The `:=` means "always assign". This is done at the start of every cycle. This tells Silice we want to always do that regardless of the state of the algorithm. However, you remain free to conditionally override the value of `leds` in the algorithm. A typical use case is to maintain low (`:=0`) and pulse high on demand (`=1`).

But then, you ask, why not also update `cnt` in this manner ? Well, excellent question, of course we can:

```c
algorithm main(output uint5 leds)
{
  uint26 cnt = 0;
  
  leds := cnt[21,5];
  cnt  := cnt + 1;
}
```

Try it, this works just as well.

> As an exercise, try to make the blinker go faster or slower by changing the bit-width of `cnt` and/or the assignment to `leds`.

