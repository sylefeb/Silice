# Silice board definitions

Each board has its own directory, and the board is added to the [list of boards](boards.json).

The board directory has to contain a (board.json)[ulx3s/board.json] file. This file specifies everything Silice needs to know about the board and its potential variants. For each variant it specifies:
- the Verilog framework file (the 'glue' between Verilog and Silice compiled code)
- the sets of pins and corresponding defines (that are defined during compilation for both Silice pre-processor and Verilog)
- the list of *builders* which are the tools for design synthesis. This is often (edalize)[], but can also be a user provided shell script, for instance.
- the bitstream programming file (result of compilation)
- the list of constraint files (typically where pin assignments and names are specified)
- the command line for programming the board

> *Important:* For your install to see the changes, Silice has to be reinstalled on your system by running the `compile_silice_(system).sh` script at the root of the repo.

## Standard pin sets

> *NEW:* There is a better way to define pins that is much more flexible, see e.g.
> the [icestick Verilog framework](icestick/icestick.v), all lines with `$$pin`
> and the macros `%TOP_SIGNATURE%`, `%WIRE_DECL%` and `%MAIN_GLUE%`. This is
> yet to be documented here, however everything described below still works.
> This new approach makes it unnecessary to define pin sets, as outputs can be
> bound to pins directly in each design, see e.g. [this example](../../projects/pins).

To simplify writing multi-board code, Silice uses standards set of pins. This is not mandatory but helps development! The most important is to preserve the pin names, the signal width are expected to vary, this can be dealt with with pre-processor definitions in the Verilog glue, see e.g. [NUM_LEDS](ulx3s/ulx3s.v).

The main pin groups are:
- basic: on-board LEDs `leds`
- buttons: `btns`
- audio: an audio DAC, `audio_l` and `audio_r`
- oled: `oled_clk`, `oled_mosi`, etc.
- sdcard: `sd_csn`, `sd_clk`, etc.
- sdram: `sdram_dq`, `sdram_clk`, etc.
- hdmi: `gpdi_dq`, `gpdi_dn`
- uart: `uart_tx`, `uart_rx`
- vga: `vga_r`, `vga_g`, `vga_b`, `vga_hs`, `vga_vs`

As an example, the [ULX3S definition](ulx3s/board.json) is one of the most complete.

## Adding a new board (example)

The best is to start from an existing board using a same toolchain, copying and renaming its directory and its content. We then add the board to the list in [boards.json](boards.json).

As an example we will be adding the `ecpix5` from *LambdaConcept*. As the board is ECP5 based we will start from the `ulx3s`. The toolchain is yosys-nexpnr, either through edalize or with a shell script.

After copying and renaming the folder and files, we start by updating `board.json`: board name (`ecpix5`), variant name (`85k`), Verilog framework (`ecpix5.v`).

Then we update the pin groups. The board has [many cool features](http://docs.lambdaconcept.com/ecpix-5/) ; we will add pin groups later for all of these but for now let's focus on the bare minimum: LEDs (group `basic`) and serial communication (group `uart`). We remove everthing else for now, so we have:
```c
"pins": [
  {"set"    : "basic"},
  {"set"    : "uart",   "define" : "UART=1"}
],
```

The board has so much more to offer - we are just getting started! (As you look at the files they'll likely have grown to include more pin definitions).

Alright, that was the easy part. We now move to the `"builders"` section. To keep things simple in the tutorial we will only keep `edalize`. The things we have to update are the `package` and `freq` parameter. [nMigen](https://github.com/nmigen/nmigen) has definitions for the board so [we'll have a look there](https://github.com/nmigen/nmigen-boards/blob/master/nmigen_boards/ecpix5.py). From this, it seems we have to use `CABGA554` for package and a frequency of 100 MHz. (Another useful resource for board definitions is the [edalize blinky](https://github.com/fusesoc/blinky)). We also have to update the `--85k` parameter to be `--um5g-85k` (found this after nextpnr-ecp5 returned an error, and then looking at nextpnr-ecp5 options).

Next we have to consider how the board will be programed. I'd like to use [openFPGALoader](https://github.com/trabucayre/openFPGALoader). The documentation [gives us the command line](http://docs.lambdaconcept.com/ecpix-5/features/debug.html#openfpgaloader). In the end we have:
```c
"builders": [
{
  "builder" : "edalize",
  "description": "Build using Edalize",
  "tool": "trellis",
  "tool_options": [
    {
        "yosys_synth_options": ["-abc9"],
        "nextpnr_options": ["--85k", "--freq 100", "--package CABGA554", "--timing-allow-fail"],
        "pnr": "next"
    }
  ],
  "bitstream"  : "build.bit",
  "constraints": [{"name": "ecpix5.lpf", "file_type": "LPF"}],
  "program": [{"cmd" : "openFPGAloader", "args" : " -b ecpix5 build.bit"}]
}
]
```

Now time to move on to the pin definitions. I could not find a `.lpf` file online so [I created one](ecpix5/ecpix5.lpf) from the documentation.

The final step is to update the [Verilog framework](ecpix5/ecpix5.v). This is the glue between the pin definitions in the lpf file and the Silice main module.

The header will be updated as:
```c
`define ECPIX5 1
$$ECPIX5   = 1
$$HARDWARE = 1
$$NUM_LEDS = 12
$$config['dualport_bram_supported'] = 'no'
```
which add definitions for both Verilog and Silice pre-processors, and also let Silice know that the ECP5 does no support true dual BRAMs. The rest defines a `top` module that passes the pins to Silice main module `M_main`. Not the use of pre-processor definitions from the pin groups (as they are selected from the Makefile during build):
```c
module top(
  // basic
  output [11:0] leds,
`ifdef UART
  // uart
  output  uart_rx,
  input   uart_tx,
`endif
  input  clk100
  );
```
So that the uart pins will only be there if the Makefile specifies `-p basic,uart` on the command line of `silice-make.py`.

The Verilog framework also takes care of providing a reset signal.

The `ecpix5` has inverted LED outputs so we use the Verilog framework to invert them before sending the signals out: `assign leds = ~__main_leds;`

And that's it! Let's try it out. We will synthesize [Silice blinky](../../projects/blinky/). Go to the `projects/blinky/` folder, open a command line, plug the board and type
```
make ecpix5
```
