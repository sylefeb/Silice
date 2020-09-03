
# Silice example projects

Looking at examples is a great way to learn and experiment. So I prepared several projects, from small to big, to show off Silice features. Some of these projects are still under active development, and evolve together with the language (DooM-chip, I am looking at you!). 

Note that these designs and entirely created from scratch with Silice, from SDRAM, VGA, OLED and LCD controlers to dividers and multipliers, importing only tiny bits of Verilog (for e.g. PLLs). Most of the designs rely on common functions grouped in the *common* folder.

To build a design please refer to the [building](#building-a-project) section below and the README of the project.
All designs can be simulated with Icarus/Verilator, and many will work right out of the box on real hardware. Please refer
to the README of each project.

Some projects require a VGA DAC (a bunch of resistors on a breadbord will do!). This is simple and fun to do, so I highly encourage you [to make one](DIYVGA.md). All VGA and SDRAM projects can be simulated with the verilator framework (see next section), which outputs images of what you would see on screen. They can also be simulated with Icarus, which outputs a fst file that can be explored with gtkwave or visualized with *silicehe*.

A few projects rely on some external hardware (typical, low cost things: OLED, keypad, LCD, etc.), this is all detailed in the README of the projects.

<p align="center">
  <img width="600" src="gallery.png">
</p>

## Building the examples

All examples are in the *projects* directory. This directory also contains a *build* subdirectory, with one entry for each currently supported framework. This includes both simulation (icarus, verilator) and FPGA hardware (icestick, mojo v3, de10nano, etc.).

To build a project, go into projects/build/*architecture* where *architecture* is your target framework. This directory contains shell scripts that take as parameter the project source file. Let's take an example! We will build the 'divint bare' demo for simulation with icarus. Do the following:

*Note:* under Windows please use a MinGW shell, please refer to the [getting started](../GetStarted.md) guide.

```
cd silice/projects/build/icarus
./icarus_bare.sh ../../projects/divint_bare/main.ice
```
If everthing goes well you should see in the last console output:
```
20043 /   -817 =    -24
```
Good news, the hardware divider is working!

## Note on OLED

To configure your OLED setup, edit the *oled.ice* file in [common/oled.ice](common/oled.ice) to specify the driver and resolution being used.
The OLED library supports the SDD1351 and ST7789 drivers. Also checkout the specific pinout used for your board.

# All examples

## VGA demo effects

Some old-school effects ported on FPGA.

*Requires*: [VGA DAC](DIYVGA.md)\
*Tested on*: IceStick Ice40, Mojo V3, ULX3S, de10nano

## VGA + SDRAM framebuffer demos

### WolfPGA

The (very simplified) render loop of Wolfenstein 3D.

*Requires*: [VGA DAC](DIYVGA.md), SDRAM\
*Tested on*: Mojo V3 + SDRAM (or HDMI) shield, ULX3S, de10nano

### The DooM-chip

The DooM-chip, pushing the limits.

*Requires*: [VGA DAC](DIYVGA.md) or OLED/LCD screen, SDRAM\
*Tested on*: de10-nano with MiSTer SDRAM board, ULX3S

## Ice-V

A cool and tiny Risc-V processor (fits a HX1K Ice40, e.g. on the IceStick).

*Tested on*: ULX3S, IceStick\
*Optional*: OLED screen

## VGA text buffer

A small demo featuring a font and text buffer

*Requires*: [VGA DAC](DIYVGA.md)\
*Tested on*: ULX3S, IceStick, Mojo V3

## Arithmetic

Divider (because we need one), multiplier and pipelined multiplier.

# Notes and tips

- If you are using an IceStick or ULX3S under Windows and run into trouble, checkout the notes on my [fpga-binutils repo](https://github.com/sylefeb/fpga-binutils) (end of page).

- Some Verilog code in *projects/common* (hdmi, sdram) comes from the [Alchitry](https://alchitry.com/) demos for the MojoV3. Also checkout [Lucid](https://alchitry.com/pages/lucid-fpga-tutorials) it is great for learning low-level FPGA programming (similar to Verilog but more beginner-friendly). The website features good tutorials on FPGAs in general.
