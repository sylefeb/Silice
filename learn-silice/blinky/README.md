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

&nbsp;
### *A first blinky*
---

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

&nbsp;
### *A second blinky, that blinks (!)*
---

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

&nbsp;
### *A blinky that does not blind us*
---

Your board might be equipped with super-bright LEDs. Mine surely is, I can barely stand looking at them. Let's fix this!

In this third version we will define a second algorithm. The goal of this algorithm will be to produce a fast one-bit blink, that is `1` only some portion of the time. So let's say that across 16 cycles, we are going to have 3 cycles at `1` and 13 at `0`. This will happen so fast that we won't see any 'blink', but instead we will perceive a loss of intensity. What we are doing here has a fancy name: [Pulse Width Modulation](https://en.wikipedia.org/wiki/Pulse-width_modulation) (or PWM). It is a super-convenient technique to fake 'intensity levels' while having a single bit output. 

First, let's define our algorithm. As it generates a signal it only has one output:

```v
algorithm intensity(output uint1 pwm_bit)
{
  uint16 ups_and_downs = 16b1110000000000000;

  pwm_bit       := ups_and_downs[0,1];
  ups_and_downs := {ups_and_downs[0,1],ups_and_downs[1,15]};
}
```

So what happens here? First, we declare `ups_and_downs` and set it to a 16 bit value with three `1`s and eleven `0`s.
Then we always set `pwm_bit` to the first bit of `ups_and_downs`. And finally, we *rotate* the bits of ups_and_downs by one. This is achieved with the concatenation operator (that comes from *Verilog* -- Silice support most of the same operators). The concatenation is a list given as `{a,b,c}`. The result is a value concatenating the bits of a, b, and c, with c in the least significant bits. (*Side note*: if constants are used they have to be given a size for this to make sense). 

So let's have a look at this: `{ups_and_downs[0,1],ups_and_downs[1,15]}`. We are concatenating 1 bit with 15 bits (recall the second part of `[ , ]` is the bit-width). This results in a new 16 bits value assigned to `ups_and_downs`, so same width. Then we can see we select the first bit `ups_and_downs[0,1]` and the fifteen *others* bits `ups_and_downs[1,15]`, and put the first bit as new last bit! Imagine this happening over a few cycles (replacing bits by their initial ranks):
```
f,e,d,c,b,a,9,8,7,6,5,4,3,2,1,0
0,f,e,d,c,b,a,9,8,7,6,5,4,3,2,1
1,0,f,e,d,c,b,a,9,8,7,6,5,4,3,2
2,1,0,f,e,d,c,b,a,9,8,7,6,5,4,3
3,2,1,0,f,e,d,c,b,a,9,8,7,6,5,4
```
See how bits leave from the right and enter back from the left? This is called a bit *rotation*.

The effect of this rotation is that `pwm_bit` will be assigned all the bits of `16b1110000000000000` in sequence, as they will all show up as the first bit of `ups_and_downs`, over and over again. So in the end the output will be `1` for 3/16th of the time

Ok great, what do we do with this? 

Next, we *instantiate* the algorithm in `main`. In Silice, because you describe hardware, any algorithm that is used has to be instantiated. This physically corresponds to allocating space on the FPGA for the circuit of the algorithm (actual allocation is done by place-and-route, *NextPNR* in our case).

Here is how main is modified to integrate the PWM:
```c
algorithm main(output uint5 leds)
{
  intensity less_intense;

  uint26 cnt = 0;
  
  leds := cnt[21,5] & {5{less_intense.pwm_bit}};
  cnt  := cnt + 1;  
}
```

The algorithm is instantiated by `intensity less_intense`. We give a name to the instance -- because of course we could run multiple instances in parallel!

Then, we use the output of the algorithm, which is accessed with the 'dot' syntax as `less_intense.pwm_bit`. 

Now, what's going on with this line? `leds := cnt[21,5] & {5{less_intense.pwm_bit}}`. 

As before we assign 5 bits of `cnt` to `leds`, but now to diminish the intensity we combine the bits of `cnt` with `less_intense.pwm_bit` using a `&` (logical and). However, if we were to write `cnt[21,5] & less_intense.pwm_bit` we would only get LED0 to light up. That is because `cnt[21,5]` is five bits while `less_intense.pwm_bit` is a single bit wide, and would be considered 0 in higher bits. Instead, we expand `less_intense.pwm_bit` to become 5 bits wide, replicating its bit five times. This is done with the expression `{5{less_intense.pwm_bit}}` (also [inherited from Verilog](https://www.nandland.com/verilog/examples/example-replication-operator.html)).

And this is it, our blinker blinks all the same, but is less bright. Play with the number of ones in `16b1110000000000000` to adjust the brightness.

> **Note:** The algorithm we defined,  `algorithm intensity`, is an *auto-start* algorithm. That means it does not need to be called or started, it always runs. The reason is that it only uses always assignments, and nothing else.

> **Note:** `main` is also an *auto-start* and is automatically instantiated for us.