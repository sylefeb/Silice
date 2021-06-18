# The Ice-V: a simple RV32I that packs a punch

## What is this?

The Ice-V is a processor that implements the RiscV RV32I specification. It is simple and compact, yet demonstrates many features of Silice and can be useful in simple designs. It is specialized to execute code from BRAM, where the code is backed into the BRAM upon synthesis. However, it would be quite easy to extend the Ice-V to boot from SPI or execute code from a RAM.

## Testing

Testing requires the RiscV toolchain. Under Windows, this is included in the binary package from my fpga-binutils repo. Under macOS, you can install from Homebrew. Under Linux you will
have to compile from source. See see [getting
started](https://github.com/sylefeb/Silice/blob/master/GetStarted.md) for more detailed instructions.

The build is performed in two steps, first compile some code for the processor to run:

From `projects/ice-v` (this directory) run:
```
./compile_c.sh tests/c/test_leds.c
```

Plug your board tp the computer for programming and, from the project folder run:
```
make icestick
```

On an IceStick the LEDs will blink around the center one.

Optionally you can plug a small OLED screen (I used [this one](https://www.waveshare.com/1.5inch-rgb-oled-module.htm), 128x128 RGB with SSD1351 driver).

The pinout for the IceStick is:
| IceStick        | OLED      |
|-----------------|-----------|
| PMOD10 (pin 91) | din       |
| PMOD9  (pin 90) | clk       |
| PMOD8  (pin 88) | cs        |
| PMOD7  (pin 87) | dc        |
| PMOD1  (pin 78) | rst       |

Equipped with this, you can test the Doom fire (tests/c/fire.c) or the starfield
(tests/c/starfield.c). 

For the DooM fire:

```
./compile_c.sh tests/c/fire.c
make icestick -f Makefile.oled
```

*Note:* the reset is not perfectly reliable; if nothing happens try unplugin/plugin
the IceStick back after programming.

## The Ice-V design

Now that we have tested the Ice-V let's dive into the code! The entire processor fits in [less than 200 lines of Silice code](ice-v.ice) (excl. comments), but there are many things to discuss.



## Links

* RiscV toolchain https://github.com/riscv/riscv-gnu-toolchain
* Pre-compiled riscv-toolchain for Linux https://matthieu-moy.fr/spip/?Pre-compiled-RISC-V-GNU-toolchain-and-spike&lang=en
* Homebrew RISC-V toolchain for macOS https://github.com/riscv/homebrew-riscv
* FemtoRV https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV
* PicoRV  https://github.com/cliffordwolf/picorv32
* Stackoverflow post on CPU design (see answer) https://stackoverflow.com/questions/51592244/implementation-of-simple-microprocessor-using-verilog
