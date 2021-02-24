# The DooM-chip

*It will run Doom forever*

## Foreword

This is the DooM-chip! A partial recreation of Doom 1993 in hardware: there is no CPU, the entire render loop and (very basic) game logic is hardcoded in LUTs, flip-flops and wires. This is very different from a source port: there is zero reuse of the original game code, everything is new and written in Silice. Only the game data is reused.

This is the first version I worked on, that was released in May-June 2020. Note that this is *not* the last version, as the Doom-chip is still evolving: a more advanced version is in the works in a different repository, but it is not yet stable enough for release.

This first version allows to interact with the environment: you can walk around levels, open/close doors and lifts, turn switches on/off. However, there is only one monster type (mostly to test sprite rendering), they do not move, and there are no weapons. As everything is stored in BRAM, textures are downsampled. This can be controlled in [pre_do_textures.lua](pre_do_textures.lua), parameter `default_shrink` (0: highest resolution, 2: lowest).

This version was my first take at the Doom-chip, developed as a proof-of-concept for Silice (itself still under active development). The synthesized hardware is large and quite low frequency, and some latest Silice features are not used. But the focus was first and foremost on making it happen!

The DooM-chip is a great example of what the Lua pre-processor has to offer. Indeed, the pre-processor automatically parses the game file data, extracts and generates all data-structures that are then embedded into BRAMs.

## Where's All the Data?

For obvious copyright reasons you have to provide your own Doom WAD file: for instance `doom1.wad`, to be placed in this directory. During compilation the data will be automatically extracted and processed. You can select the level in the header of [doomchip.ice](doomchip.ice) (see the "ExMy" string).

The DooM-chip also works with WAD files from the [freedoom project](https://freedoom.github.io/).

## How to run

### In simulation

Open a shell in this directory and launch ```make verilator```

Images will be produced in the directory, the third one (`vgaout_0002.tga`) should reveal a view of E1M1! (the two first are black as this corresponds to memory and chip reset/warmup).

### Running on the ULX3S + HDMI

Plug the board to USB and launch ```make ulx3s```

Done! (takes ~ 0.5 hour)

*Note:* make sure you use a 64 bits toolchain, synthesis requires a lot of RAM (10+ GB).

### Running on the ULX3S + OLED screen

The default is a ST7789 240x240 screen ; these are inexpensive (~ $6) and some models plug directly into the OLED connector of the ULX3S (you'll have to solder the connector if not present, it is located just below the ECP5).

The OLED library supports also an SSD1351 driver, and other resolutions, but you'll have to edit the source code to customize for that: see configuration at the top of [oled_doomchip.ice](oled_doomchip.ice).

Plug the board to USB and launch ```make ulx3s-oled```

Done! (takes ~ 0.5 hour)

*Note:* make sure you use a 64 bits toolchain, synthesis requires a lot of RAM (10+ GB).

### Other boards?

The Doom-chip was initially developed on a de10-nano ([MiSTer setup](https://github.com/MiSTer-devel/Main_MiSTer/wiki)) with [VGA DAC](../DIYVGA.md) (or MiSTer IO board) and SDRAM. This should still work, compiling with `make de10nano`, but has not been thoroughly tested in a while.
