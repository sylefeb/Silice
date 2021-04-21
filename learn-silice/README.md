# Learn FPGA programming with Silice

This page covers introductory topics. For more advanced topics please checkout the [advanced topics](Advanced.md) page.

Silice has a [reference documentation](Documentation.md).

Beyond the tutorials below, there are many [example projects to learn from](../projects/README.md).

## What do you need?

These tutorials works with the following boards: IceStick, IceBreaker, ULX3S. (*Note:* and many other boards with minimal changes). 

The IceStick and IceBreaker are great first options. The IceStick is small (1280 LUTs) but can still host many cool projects (all Silice [VGA demos](../projects/vga_demo) as well as Silice [tiny Ice-V RISC-V processor](../projects/ice-v) work on it!). The IceBreaker is ~5 times larger (5280 LUTs) and offers a lot more connectivity. The ULX3S is great for both simple and advanced projects.

The first parts of the tutorial requires only the boards, while the second part explores using a few peripherals: OLED screen, matrix LED panel, VGA. 

## Start learning

We will cover the following topics, each introducing new concepts of Silice and some fun peripherals.
1. [Blinking LEDs](blinky/README.md) the *Hello world* of FPGA. Provides an introduction to many basic elements of Silice. Read first!
1. (*coming soon*) Simulating your designs.
1. (*coming soon*) UART communication.
1. (*coming soon*) OLED screens.
1. (*coming soon*) VGA.
1. (*coming soon*) SDRAM.

## Do more!

The following demos are compatible with the IceStick and IceBreaker:
- [Ice-V RV32I RISC-V processor](../projects/ice-v/README.md)
- [VGA demos](../projects/vga_demo/README.md)

The terrain demo was designed for the IceBreaker:
- [Terrain](../projects/terrain/README.md)

The HDMI framework for the ULX3S:
- [HDMI framework](../projects/hdmi_test/README.md)
