# Building for the de10nano board (Altera CycloneV) using yosys synthesis

These build scripts will let you synthesize a netlist using yosys and synth_intel_alm
targetting the CycloneV FPGA. Once the netlist is synthesized it goes through 
Quartus place and route, so you need Quartus to be installed.

Currently, this is primarily targetting a de10nano setup with SDRAM and a [VGA DAC](../../DIYVGA.md).
However, it should be fairly straightforward to adapt this to other boards and setups,
let me know if you run into any trouble!

Make sure to use the very latest version of yosys.

## BRAM initialization

A downside of this approach is that Quartus requires BRAM initialization data to
be in external files (one 'MIF' file per BRAM), which does not fit the yosys output.

To make this work I prepared a post-processing script that takes the output of 
yosys+synth_intel_alm and extracts the init files. However, this requires a few
changes to your yosys setup. Do not worry, this is very simple:
- first, locate your yosys install 'share' directory that contains the subdirectory 'share/intel_alm/common'
- edit 'bram_m10k.txt', change 'init   0' for 'init   1'
- edit 'quartus_rename.v', in the MISTRAL_M10K module add
```parameter [10239:0] INIT = 10240'bx;```
- below, just after ```.port_b_read_enable_clock("clock0")``` add a coma and then 
```.mem_init0(INIT)```
- edit 'mem_sim.v', in the MISTRAL_M10K module add
```parameter [10239:0] INIT = 10240'bx;```

Should be all good!

## Usage

This has been tested with the following projects:
- vga_demo/*.ice
- sdram_vga_test/
- doomchip/
- vga_wolfpga/

To synthesize a design call:
```./yosys_de10nano_sdram_vga_64.sh <ice file>```

At the end of synthesis the design is in the directory output_files (project.sof)
and you can use the Quartus programmer to upload it to the de10nano.

## Links:
- https://github.com/Ravenslofty/yosys-cookbook/blob/master/cyclone_v.md
