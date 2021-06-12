# Silice Verilator simulation framework

This simulation framework is used everytime a Silice design is compiled with `make verilator`. There are three variants:

1. [verilator_bare](verilator_bare.cpp) for basic simulation.
1. [verilator_vga](verilator_vga.cpp) for simulation with VGA output.
1. [verilator_vga](verilator_vga_sdram.cpp) for simulation with VGA output and an SDRAM memory chip.

In particular 3. works great to simulate boards such as the ULX3S or de10-nano with an SDRAM MiSTer module.

Both 2. and 3. open a window showing the simulation output. This is achieved with `glut` and `OpenGL`, so freeglut has to be installed on the system (packages are often called `freeglut3` and `freeglut3-devel`, on MinGW it is simply `freeglut`).

For more details on how the graphical output is performed see comments in [VgaChip.cpp](VgaChip.cpp) and [vga_display.cpp](vga_display.cpp).

To see how this gets compiled from Silice to Verilog and then Verilator see the script [verilator.sh](../boards/verilator/verilator.sh).

Here is an example of [`projects/vga_demo/vga_flyover3d.ice`](../../projects/vga_demo/README.md)

<p align="center">
  <img width="500" src="flyover_simul.gif">
</p>

This works with most projects, including [WolFPGA](../../projects/wolfpga/README.md) and the [Doom-chip](../../projects/doomchip/README.md).