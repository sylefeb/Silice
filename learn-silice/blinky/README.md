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

So when we run this design, the only thing that happens is that we lit all LEDs but one (LED0, in the center).

We could have written this more concisely. In Silice, outputs can have default value, so we can simply write:

```c
algorithm main(output uint5 leds = 5b11110)
{

}
```

&nbsp;
### *A second blinky, that blinks (!)*
---
Source code: [blinky1.ice](blinky1.ice).

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
Source code: [blinky2.ice](blinky2.ice).

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

&nbsp;
### *Blink me five*
---
Source code: [blinky3.ice](blinky3.ice).

Let's do a blinker that blinks five times in a short sequence, pauses for a longer time, and loops back.

For this we need two delays. A short one for the five blinks sequence, and a longer one for the pause. To produce these delays we will define a `wait` algorithm:

```c
algorithm wait(input uint32 delay)
{
  uint32 cnt = 0;
  while (cnt != delay) {
    cnt = cnt + 1;
  }
}
```
This takes a delay as input (a 32 bits integer, likely overkill!), and increments a counter (`cnt`) until it reaches the same value.

Now, lets see how the rest of our blinker looks:

```c
algorithm main(output uint5 leds)
{
  wait waste_cycles;

  while (1) {
    uint3 n = 0;
    while (n != 5)  {
      // turn LEDs on
      leds = 5b11111;
      () <- waste_cycles <- (3000000);
      // turn LEDs off
      leds = 5b00000;
      () <- waste_cycles <- (3000000);
      n = n + 1;
    }
    // long pause
    () <- waste_cycles <- (50000000);
  }
}
```

First, we instantiate the algorithm with `wait waste_cycles`.

Then we have two nested loops, the outer infinite loop `while (1) { ... }` and the inner loop for the five blinks `while (n != 5)  { ... n = n + 1; }`.

Now to the interesting part, the calls to `wait`. This is an algorithm that defines a sequence of steps, so it has to be called to run. The calls use the syntax `(o0,...,oN) <- alg <- (i0,...,iM)` with outputs on the left and inputs on the right. Here, since we have one input and no outputs we call with `() <- waste_cycles <- (3000000)`. This starts the algorithm *and* waits for its completion, which takes 3000000 cycles (249 milliseconds at 12MHz). 

Now that we can call the `wait` algorithm, things are simple:
1. we turn the LEDs on: `leds = 5b11111`
1. wait 3000000 cycles: `() <- waste_cycles <- (3000000)`
1. we turn the LEDs off `leds = 5b11111`
1. wait 3000000 cycles `() <- waste_cycles <- (3000000)`
1. do this five times `while (n != 5)  { ... n = n + 1; }`
1. wait 50000000 cycles `() <- waste_cycles <- (50000000)`
1. loop forever! `while (1) { ... }`

> **Note:** As an exercise, make a sequence of 5 blinks, then 10, then 5, etc.

&nbsp;
### *Blink them all!*
---
Source code: [blinky4.ice](blinky4.ice).

Our goal now is to give different blink sequences to each of the five LEDs. We would like LED0 to blink once then pause, LED1 to blink twice then pause, etc. But we want these sequence to start at the same time and stay in sync, so shorter sequences wait for the longest one.

There are many ways we could achieve this, and here we will took the opportunity to discover asynchronous calls to algorithms. Just note this is not be best way to achieve this result, simply an opportunity to introduce a new feature!

So, we will reuse the blink sequence we defined in [blinky3.ice](blinky3.ice), and customize it for each LED.
We move the blink sequence to an algorithm driving a single led (algorithm `wait` is unchanged):

```c
algorithm blink_sequence(output uint1 led,input uint3 times)
{
  wait waste_cycles;

  uint3 n = 0;
  while (n != times)  {
    // turn LED on
    led = 1;
    () <- waste_cycles <- (3000000);
    // turn LED off
    led = 0;
    () <- waste_cycles <- (3000000);
    n = n + 1;
  }
  // long pause
  () <- waste_cycles <- (50000000);
}
```

This is the same as before, but we only output a one bit `led` value.

Next, we instantiate this sequence five times in main (one per LED):

```c
algorithm main(output uint5 leds)
{
  blink_sequence s0;
  blink_sequence s1;
  blink_sequence s2;
  blink_sequence s3;
  blink_sequence s4;
```

We then always assign the outputs of these algorithms to `leds`, concatenating them in a 5 bits value:

```c
leds := {s4.led,s3.led,s2.led,s1.led,s0.led};
```

Finally, we are ready to call the algorithms generating the sequences. But what if we call them in sequence?

```c
  while (1) {
    () <- s0 <- (1);
    () <- s1 <- (2);
    () <- s2 <- (3);
    () <- s3 <- (4);
    () <- s4 <- (5);
  }
```

We won't get the desired effect. Instead, each LED will do its full sequence before the next one starts. 

Instead we want the sequences to start *in parallel*. And we can just do that! In fact, the calls `() <- alg <- ()` are composed of two parts. First the call that triggers the algorithm `alg <- ()` (the *async call*) and then the wait for termination `() <- alg` (the *join*). Thus we can do the following:

```c
  while (1) {
    s0 <- (1);
    s1 <- (2);
    s2 <- (3);
    s3 <- (4);
    s4 <- (5);
    // wait for longest to be done
    () <- s4;
  }
```

Here we call *at the same time* all five sequences. An *async* call takes no time, so all algorithms are started during the same cycle. Then we wait for the longest of the batch to be done, which is `s4`.

And voilà! A fancy parallel blinking sequence in hardware.

&nbsp;
### *Blink smoothly*
---
Source code: [blinky5.ice](blinky5.ice).

As a last example we will now create a smoothly pulsing sequence. This will reveal how an algorithm can be an auto-start, and yet continuously receive inputs and adapt its outputs.

We first revisit the intensity (PWM) algorithm of [blinky2.ice](blinky2.ice), but modify it so that it takes an input defining how many `1`s and `0`s are in the 16 bits sequence:

```c
algorithm intensity(
  input  uint4 threshold,
  output uint1 pwm_bit)
{
  uint4 cnt = 0;

  pwm_bit  := (cnt <= threshold);
  cnt      := cnt + 1;
}
```

The algorithm now has an internal counter (`uint4 cnt`) that is always incremented -- it wraps back to 0 after reaching 15, so it generates a sequence 0, 1, 2, ..., 15, 0, 1, 2, ...
The counter is compared to a threshold, and the result in `pwm_bit` is used as the output (a single bit). So if threshold == 0 then `pwm_bit` is `1` during 1/16 cycles ; if  threshold == 15 then `pwm_bit` is always `1`. This will control the LEDs intensity.

Here is how we use this algorithm in `main`:

```c
algorithm main(output uint5 leds)
{
  uint4  th = 0;
  uint1  pb = 0;
  intensity pulse(
    threshold <: th,
    pwm_bit   :> pb
  );

  uint20 cnt          = 0;
  uint1  down_else_up = 0;

  leds := {5{pb}};
  
  while (1) {
    if (cnt == 0) {      
      if (down_else_up) {
        if (th == 0) {
          down_else_up = 0;
        } else {
          th = th - 1;
        }
      } else {
        if (th == 15) {
          down_else_up = 1;
        } else {
          th = th + 1;
        }
      }
    }
    cnt = cnt + 1;
  }
}
```

The important Silice feature being introduced here, is that variables `th` and `pb` are *bound* to the algorithm instance `intensity pulse`. 

`th` is bound to the input `threshold` using the `<:` operator (`threshold <: th`). `pb` is bound to the output `pwm_bit` using the `:>` operator (`pwm_bit :> pb`). 

This means that `th` and `pb` are now directly linked to the input/output of the algorithm. Any change to `th` in `main` is reflected onto `threshold` of `pulse`, and any change to `pwm_bit` of `pulse` is reflected onto `pb` in `main`. 

Note that there is a one cycle latency between a change onto `pwm_bit` in `pulse` and the change on `pb` in `main`, see the [notes on algorithms calls, bindings and timings](../AlgoInOuts.md) for all details. But here this has no impact.

Alright, so `pulse` always runs in parallel to `main` and whenever we change `th` it adapts its output which we get in `pb`. The `leds` are set to the value of `pb` with `leds := {5{pb}}`. The rest of the algorithm simply implements a slow pulse, an increase/decrease sequence on `th`. 

We use another `cnt` in `main` to slow things down, only acting when `cnt == 0`, while `cnt` is incremented every cycle (`cnt = cnt + 1`).  

We use `down_else_up` to tag whether we should increment or decrement `th`. Then, we increment `th` to `15` and reverse direction (`down_else_up = 1`). We decrement `th` to `0` and reverse again  (`down_else_up = 0`). This keeps going forever.

This is it, we have a slow pulse! 

Binding algorithms to variables, as we did here with `threshold <: th` and `pwm_bit :> pb` is extremely common. In particular, these bindings can link together memory interfaces and CPUs, controllers and arbiters, outputs and signal drivers (VGA/HDMI/UART/etc.). 

> **Note:** we could also have used `pulse.pwm_bit` and skip `pb`, but the goal was to demonstrate bindings both for input and outputs

&nbsp;
### *Conclusion*
---

Through these variations on blinky we have seen quite a few features of Silice already -- but not all ;) Time to experiment for yourself! Make something fun, explore the [many example projects](../../projects/README.md), and let me know what you come up with! (reach me on twitter, [@sylefeb](https://twitter.com/sylefeb)).
