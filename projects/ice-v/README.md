# Silice risc-v RV32I implementation

Fits in an IceStick!

Requires the RiscV toolchain. Under Windows, this is included in the binary 
package from my fpga-binutils repo (see [Getting
started](https://github.com/sylefeb/Silice/blob/master/GetStarted.md)). Under
macOS, you can install from Homebrew; see below. Under Linux you will
have to compile from source (afaik there is no package yet?), see links below.

Builds in two steps, first compile some code for the processor to run:

In the *projects/ice-v* folder (here!) run
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
| IceStick     | OLED      |
|--------------|-----------|
| BR3 (pin 62) | din       |
| BR4 (pin 61) | clk       |
| BR5 (pin 60) | cs        |
| BR6 (pin 56) | dc        |
| BR7 (pin 48) | rst       |

Equipped with this, you can test the Doom fire (tests/c/fire.c) or the starfield
(tests/c/starfield.c). Use `make icestick -f Makefile.oled` to synthesize the
design and program the board.

*Note:* the reset is not perfectly reliable; if nothing happens try unplugin/plugin
the IceStick back after programming.

## Links

* RiscV toolchain https://github.com/riscv/riscv-gnu-toolchain
* Pre-compiled riscv-toolchain for Linux https://matthieu-moy.fr/spip/?Pre-compiled-RISC-V-GNU-toolchain-and-spike&lang=en
* Homebrew RISC-V toolchain for macOS https://github.com/riscv/homebrew-riscv
* FemtoRV https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV
* PicoRV  https://github.com/cliffordwolf/picorv32
* Stackoverflow post on CPU design (see answer) https://stackoverflow.com/questions/51592244/implementation-of-simple-microprocessor-using-verilog
