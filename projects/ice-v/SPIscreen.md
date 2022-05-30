## SPI screen

For the OLED/LCD screen, I mainly use [this model](https://www.waveshare.com/1.5inch-rgb-oled-module.htm) (128x128 RGB with SSD1351 driver). Any other screen with the same specs will do ; otherwise changes to [src/oled.h](src/oled.h) will be required.

---

## Icebreaker

On the IceBreaker use PMOD1A to connect the SPIscreen.

> **Beware**: Double check not having plugged anything in the wrong orientation (VCC wire!): this may result in damage to the screen, the board, or both...

The pinout for the screen on the Icebreaker is:
| PMOD (name/FPGA pin) | OLED      |
|----------------------|-----------|
| P1A1   (pin 4)       | rst       |
| P1A2   (pin 2)       | dc        |
| P1A3   (pin 47)      | clk       |
| P1A4   (pin 45)      | din       |

The CS pin of the screen has to be grounded. One way to do this is to plug it on
the second ground pin of the PMOD connector

---

## Icestick

> **Beware**: Double check not having plugged anything in the wrong orientation (VCC wire!): this may result in damage to the screen, the board, or both...

Two different pinouts are supported. The first, shown next, uses all five wires
of the OLED/LCD:
| IceStick        | OLED      |
|-----------------|-----------|
| PMOD1  (pin 78) | rst       |
| PMOD7  (pin 87) | dc        |
| PMOD8  (pin 88) | cs        |
| PMOD9  (pin 90) | clk       |
| PMOD10 (pin 91) | din       |

> Using this pinout, build the design with the `Makefile.oled` makefile (see below).

> The IceV conveyor supports only this pinout on the Icestick.

The second, recommended pinout uses only four wires of the OLED/LCD interface,
leaving room for a second peripheral (such as a sound chip!). The pinout then is:
| IceStick        | OLED      |
|-----------------|-----------|
| PMOD1  (pin 78) | rst       |
| PMOD2  (pin 79) | dc        |
| PMOD3  (pin 80) | clk       |
| PMOD4  (pin 81) | din       |

The CS pin of the screen has to be grounded. One way to do this is to plug it on top of the ground pin plug, see the orange wire in the picture below.

<p align="center">
  <img src="oled-pmod-4wires.jpg" width=400px>
</p>

> Using this pinout, build the design with the `Makefile.pmod` makefile (see below).
