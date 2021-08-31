
# Silice example projects

Looking at examples is a great way to learn and experiment. So I prepared several projects, from small to big, to show off Silice features. These projects are at various degrees of maturity and complexity, some have detailed explanations and code walk-through in their README (see list below). 

Note that these designs are entirely created from scratch with Silice, from SDRAM, HDMI, VGA, OLED/LCD controlers to dividers and multipliers, importing only tiny bits of Verilog (for e.g. PLLs). Most of the designs rely on common functions grouped in the `common` folder, which is a treasure trove of functionalities that can be reused in your own designs: UART, keypads, OLED/LCD screens controllers, HDMI, VGA, SDRAM controllers, etc. 

To build a design please refer to the [building](#building-the-examples) section below and the README of the project.
All designs can be simulated with Icarus/Verilator, and many will work right out of the box on real hardware. This directory also contains a `test_all.sh` script which is mostly meant for development: it allows to check that all projects still compile with the latest Silice version. It relies on a `configs` file defined in each project sub-directory.

A few projects rely on some external hardware (typical low cost peripherals: OLED, keypad, LCD 1602, etc.), this is all detailed in the README of the projects. See also the [peripherals](#peripherals) Section below.

<p align="center">
  <img width="600" src="gallery.png">
</p>

## All example projects

For projects that do not have a README, please refer to [building the examples](#building-the-examples) below.

- LEDs and basics
  - [blinky](blinky/README.md) (detailed code walkthrough)
  - [buttons_and_leds](buttons_and_leds/buttons_and_leds.ice)
  - [using inout](inout/README.md)
  - [UART echo](uart_echo/uart_echo.ice)
- Audio
  - [streaming audio from sdcard](audio_sdcard_streamer/README.md) (detailed code walkthrough)  
  - [I2S PCM audio](i2s_audio/README.md) (detailed code walkthrough)
- Graphics
  - [HDMI tutorial](hdmi_test/README.md) (detailed code walkthrough)
  - [Voxel terrain fly-over](terrain/README.md) (detailed code walkthrough)
  - [DooM-chip](doomchip/README.md)
  - [Wolfenstein 3D render loop](wolfpga/README.md)
  - [VGA demo (text + starfield)](vga_text_buffer/vga_text_buffer.ice)
  - [VGA old-school demos](vga_demo/README.md) (fun to try!)
  - [VGA test](vga_test/vga_test.ice)
  - [LCD driver](lcd_test/README.md)
  - [SDRAM framebuffer framework test](video_sdram_test/video_sdram_test.ice)
- OLED/LCD
  - [sdcard raw dump and image viewer](oled_sdcard_test/README.md)
  - [Text display (ULX3S)](oled_text/oled_text.ice)
  - [Basic test](oled_test/oled_test.ice)
- Memory
  - [SDRAM tutorial](sdram_test/README.md) (detailed code walkthrough)
  - [SDRAM test utility](sdram_memtest/sdram_memtest.ice)
  - [bram interface](bram_interface/main.ice)
  - [bram write mask](bram_wmask/main.ice)
- RISC-V
  - [The ice-v and ice-v-dual](ice-v/README.md) (detailed code walkthrough)
  - [fire-v + graphics](fire-v/README.md) (detailed code walkthrough)
- dynamic configuration (ice40)
  - [ice40-warmboot](ice40-warmboot/README.md) (detailed explanations)
  - [ice40-dynboot](ice40-dynboot/README.md) (detailed explanations)
- Arithmetic
  - [division, standard](divstd_bare/main.ice)
  - [division, parallel](divint_bare/main.ice)
- Algorithms
  - [pipelined sort](pipeline_sort/README.md) (detailed code walkthrough) 
  - [model synthesis / wave function collapse](vga_wfc/vga_wfc_basic.ice)

## Detailed tutorials

Some of the projects have more detailed explanations and walk-throughs:

## Building the examples

All examples are in the *projects* directory. 

To build a project, make sure your board is ready to be programmed, open a command line (MinGW64 under Windows), enter the project directory and type `make <target board>` ; for instance `make icestick`. 

Let's take an example! We will build the 'divint bare' demo for simulation with icarus. Do the following:

*Note:* under Windows please use a MinGW shell, please refer to the [getting started](../GetStarted.md) guide.

```
cd silice/projects/divint_bare
make icarus
```
If everthing goes well you should see in the last console output:
```
20043 /   -817 =    -24
```
and a gtkwave window opens to let you explore the produced signals.

A good project to start with Silice is *silice/project/blinky*.

## Peripherals

### VGA

Some projects require extra hardware, for instance a VGA DAC (a bunch of resistors on a breadbord will do!). This is simple and fun to do, so I highly encourage you [to make one](DIYVGA.md). You may also use a VGA PMOD on the IceBreaker, e.g. the one by *Digilent* works great (see e.g. the [terrain](terrain/README.md) project). 

All VGA and SDRAM projects can be simulated with the verilator framework (see next section), which opens a window and shows the rendering on screen. Most projects can also be simulated with Icarus, which outputs a fst file that can be explored with *gtkwave*.

### OLED

Some of the projects use a small OLED/LCD screen. I typically use a [128x128 OLED screen with a SSD1351 driver](https://www.waveshare.com/1.5inch-rgb-oled-module.htm).

The OLED/LCD screen library in `common` is compatible with multiple drivers (feel free to contribute more!). You may configure your OLED/LCD setup by editing the [common/oled.ice](common/oled.ice) to specify the driver and resolution being used. Note however that some projects have their own controllers.
The OLED/LCD library supports the SDD1351 and ST7789 drivers. Also checkout the specific pinout used for your board.

I now typically wire OLED/LCD screens with a four wire interface, as shown below for the IceStick. Most demos support this new pinout but please refer to each project README.

# Examples highlights

## Blinky

Blinks LEDs on all supported boards.

## VGA demos

### Old-school effects

Some old-school effects ported on FPGA.

*Requires*: [VGA DAC](DIYVGA.md)\
*Tested on*: IceStick, IceBreaker (VGA pmod), ULX3S (VGA DAC), de10nano (MiSTer SDRAM, VGA DAC or MiSTer I/O board)

### VGA text buffer

A small demo featuring a font and text buffer

*Requires*: [VGA DAC](DIYVGA.md)\
*Tested on*: ULX3S (VGA DAC), IceStick, IceBreaker (VGA pmod), de10nano (MiSTer SDRAM, VGA DAC or MiSTer I/O board)

## Video demos with SDRAM framebuffer

### WolfPGA

The (very simplified) render loop of Wolfenstein 3D.

*Requires*: [VGA DAC](DIYVGA.md) or HDMI, SDRAM\
*Tested on*: ULX3S (HDMI), de10nano (MiSTer SDRAM, VGA DAC or MiSTer I/O board)

### The DooM-chip

The DooM-chip, pushing the limits.

*Requires*: [VGA DAC](DIYVGA.md) or OLED/LCD screen, SDRAM\
*Tested on*: ULX3S (HDMI), de10nano (MiSTer SDRAM, VGA DAC or MiSTer I/O board)

## Ice-V

A cool and tiny Risc-V processor (fits a HX1K Ice40, e.g. on the IceStick). Now includes a dual-core version! (only slightly bigger, still fits the IceStick!)

*Tested on*: ULX3S, IceStick, IceBreaker\
*Optional*: OLED/LCD screen, audio I2S

## Arithmetic

Divider (because we need one), multiplier and pipelined multiplier.

## Algorithms

[Pipelined sort](pipeline_sort/) (with detailed explanations)

# License

All projects are under the [MIT license](../LICENSE_MIT). Feel free to reuse!
