# Learn FPGA programming with Silice

Want to learn how to design hardware with Silice? This is the right place! Before we dive into tutorials, a few pointers:
- Silice has a [reference documentation](Documentation.md) you might want to browse through after taking these first steps.
- For quick links to advanced topics see the [advanced topics](Advanced.md) page.
- Beyond the tutorials below, there are many [example projects to learn from](../projects/README.md).

## What do you need?

These tutorials work with the following boards: IceStick, IceBreaker, ULX3S (and many other boards with minimal changes).

The IceStick and IceBreaker are great first options. The IceStick is small (1280 LUTs) but can still host many cool projects (all Silice [VGA demos](../projects/vga_demo) as well as Silice [tiny Ice-V RISC-V processor](../projects/ice-v) work on it!). The IceBreaker is ~5 times larger (5280 LUTs) and offers a lot more connectivity. The ULX3S is great for both simple and advanced projects.

The first tutorial requires only the boards, while others explore using a few peripherals: UART, OLED screen, VGA / HDMI, SDRAM. 

## Start learning!

We will cover the following topics, each introducing new concepts of Silice and some fun peripherals. The first tutorial dives into many fundamentals of Silice, through six different versions of *blinky*. Read it first!

1. [Blinky](blinky/README.md) explores variants of the *hello world* of FPGA with Silice. Provides an introduction to many basic elements of Silice. Read first!
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

The DooM-chip demo revisits the Doom render loop in hardware (ULX3S):
- [The DooM-chip](../projects/doomchip/README.md)
