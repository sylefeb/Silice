# A music player (wip)

This classroom project targets the [ULX3S board](https://radiona.org/ulx3s/) with a [SSD1351 128x128 pixel OLED screen](https://www.waveshare.com/1.5inch-rgb-oled-module.htm).

> **Warning**: Double check the SPIscreen connection to the board, in partiuclar
the GND/VCC wires!

> **Warning:**  When playing with audio, beware that the generate sounds can be
loud and very high pitched (especially when debugging!). Always reset volume to
a minimum before programming the board.

## How to use

> `make ulx3s FIRMWARE=<firmware>` where firmware is a C file (without extension)
located in the `./firmware directory`.

For the board: `make ulx3s FIRMWARE=test_menu` (plug the ULX3S first).

For simulation: `make verilator FIRMWARE=test_menu`.


## Exercises

- Add a memory mapping to buttons, update `test_menu` to use them.
- Use FAT32 to display file names in menu,
see [`void fl_listdirectory(const char *path)`](firmware/fat_io_lib/src/fat_filelib.c).
- Add the ULX3S audio output to the SOC (*), memory map it, add `sound.c` to firmware.
Write a `test_audio.c` firmware playing a few tones.
- Play tracks from the sdcard! Encode the tracks as uncompressed wave file, PCM mono 8 bits at (for instance) 11.025KHz (use e.g. Audacity, "export", "other uncompressed formats", "raw", "unsigned 8 bits PCM"). Of these 8 bits, send only the top four to the audio outputs.
- We'll recognize the music, but sound quality will be terrible. To improve, implement a hardware audio PWM
([what's the idea?](https://electronics.stackexchange.com/questions/239442/audio-using-pwm-what-is-the-principle-behind-it)).
- Make it look good.
- (advanced) Add visual effects to the player, synched with music.

> **(*)** Adding the audio implies modifying the [Makefile](Makefile) to add
`audio` to the list of peripherals (after `...,buttons`),
adding `output uint4 audio_l` and `output uint4 audio_r` to the SOC output list,
mapping these outputs as peripherals in the SOC, and finally exposing these
bindings to the firmware.

## Credits

- Uses the absolutely excellent FAT32 lib by @ultraembedded https://github.com/ultraembedded/fat_io_lib (included as a sumbodule, see README and LICENSE in [firmware/fat_io_lib](firmware/fat_io_lib).
