# ice40 warm boot tutorial

This is a tutorial explaining how to use the dynamic reboot + reconfigure-from-SPI-flash capability of the ice40 FPGA family, using the SB_WARMBOOT primitive.

> **Note:** this should work on any ice40, but as I needed an onboard button I made the demo for the IceBreaker. This is expected work on Fomu and IceStick (and others) as long as a button is available.

> **Note:** Special thanks to @juanmard and @unaimarcor for help doing this tutorial -- see links down below.

## Testing

*From binary*

Plug the icebreaker, then from a command line in this directory:
`iceprog bin/multi.bin`

*From source*

Plug the icebreaker, then from a command line in this directory:
`make program`

## Dynamic what?

When the ice40 FPGA starts it loads its configuration from SPI flash. The cool thing is that multiple bitstreams can be stored in SPI (four by default but [@juanmard found a way to extend that](https://twitter.com/juanmard/status/1388217639655313409)) *and your design can dynamically ask for a reboot, loading another bitstream*.

This is huge! 

So for instance you can pack several demos together and switch when pressing a button. I feel this opens the door to many tricks in the future, only scratching the surface here.

## How to

At first I was a bit confused, but this really is simple. Let's learn by practice!

In this demo we create two different blinker designs. The first, [blinky1.ice](blinky1.ice) blinks the red LED. The second, [blinky2.ice](blinky2.ice) blinks the green LEDs. 

Both are compiled independently as usual, see the [Makefile](Makefile). This obtains two bitstreams, `blinky1.bin` and `blinky2.bin`. You can program the board with one or the other and get the expected blinking effect.

But now let's pack them together, and enable switching when pressing button 1!

First, we modify both designs in the same way. We import a Verilog module [ice40_warmboot.v](ice40_warmboot.v). The Verilog code for this module is straightforward, it simply encapsulates the `SB_WARMBOOT` ice40 primitive:

```v
module ice40_warmboot(
	input boot,
	input [1:0] slot
	);
  SB_WARMBOOT wb( 
      .BOOT(boot),
      .S0(slot[0]),
      .S1(slot[1])
  );
endmodule
```

What does this do? When `boot` goes to high it will *reset* the FPGA and load one of four configuration bitstreams as indicated by `slot`. These four configurations are of course stored in SPI flash, but how does the FPGA know the address? In fact, it expects the addresses to be at the start of the SPI flash, in a small table of four entries. That means we have to somehow create this data ... but of course [project icestorm](https://github.com/YosysHQ/icestorm) already has all the fancy tooling! In this case `icemulti`. More on that later, let's go back to the code of our blinkers.

Here is how we use `ice40_warmboot` (`blinky1`):

```c
uint1  boot(0);
uint2  slot(0);
ice40_warmboot wb(boot <: boot,slot <: slot);
  	
slot     := 2b01; // go to blinky2
```

We instantiate and bind the module to `boot` and `slot`, and then always set `slot` to `2b01`. Why? Because `blinky1` will be in slot 0 and `blinky2` in slot 1. So `blinky1` resets to slot 1 (going to `blinky2`) and `blinky2` resets to slot 0 (going back to `blinky1` in a loop!). And indeed, the line in `blinky2` is changed to:

```c
slot    := 2b00; // go to blinky1
```

The only small difficulty is to properly handle button presses to set `boot` high. Here is the code (same in both designs):

```c
rbtns  ::= btns;  // register input buttons
boot    := boot | (pressed & ~rbtns[0,1]); // set high on release
pressed := rbtns[0,1]; // pressed tracks button 1
```

Because the buttons are asynchronous we first register them with `::=` in `rbtns`. Then we implement a small filter that will set `boot` to high (and keep it there -- that is important) when button 1 is *released*. 

Now, we only have to synthesize both bitstreams and pack the files together with `icemulti` (takes care of creating the header table):
```
icemulti blinky1.bin blinky2.bin -o multi.bin
```

This will work only up to four bitstreams with the default `icemulti`, but @juanmard generalized the process! Check the links down below.

> **Note:** `icemulti` also allows to select which of the four bitstreams is loaded after a reset, using the `-pN` options (with N the image to use upon reset). 

> **Note:** @juanmard suggests the following approach: place a bootloader with SB_WARMBOOT in this reset-selected image (e.g. a menu) which then jumps to the user-choosen image. This image does not need to jump back, a reset will do the trick. So the loaded bitsteams *do not even have to be specially written!*

> **Note:** Technically the reset-selected bitstream could be a fifth one, but this is currently not supported by `icemulti` (@juanmard version does support this, and more). 

And finally, we can program the icebreaker and test!
```
iceprog multi.bin
```

This stuff is quite amazing, isn't it ?!

## Links
- @juanmard made a similar demo (back in 2017, great stuff!) using IceStudio/Verilog https://github.com/juanmard/screen-warmboot
- @juanmard extension to many bitstreams https://github.com/juanmard/icestorm/
- Twitter discussion about this with @unaimarcor
 and @juanmard: https://twitter.com/unaimarcor/status/1388154223280467971
- SB_WARMBOOT documentation http://www.latticesemi.com/~/media/LatticeSemi/Documents/ApplicationNotes/IK/iCE40ProgrammingandConfiguration.pdf
