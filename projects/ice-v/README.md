Silice risc-v RV32I implementation

Fits in an IceStick!

Builds in two steps, first compile some code for the processor to run:

In the *projects/ice-v* folder (here!) run
```
./compile_c.sh tests/c/test_leds.c
```

Plug your board tp the computer for programming and in the *projects/build/icestick* folder run:
```
./icestick_bare.sh ../../ice-v/ice-v.ice
```

On an IceStick the LEDs will blink rapidely around the center one.

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
(tests/c/starfield.c). Use the script ./icestick_**oled**.sh to synthesize the
design and program the board.


*Note:* the reset is not always reliable; if nothing happens try unplugin/plugin
the IceStick back after programming.

Links

* FemtoRV https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV
* PicoRV  https://github.com/cliffordwolf/picorv32
* Stackoverflow post on CPU design (see answer) https://stackoverflow.com/questions/51592244/implementation-of-simple-microprocessor-using-verilog
