# A music player

This classroom project targets the [ULX3S board](https://radiona.org/ulx3s/) with a [SSD1351 128x128 pixel OLED screen](https://www.waveshare.com/1.5inch-rgb-oled-module.htm).

> **Warning**: Double check the SPIscreen connection to the board, in particular the GND/VCC wires!

> **Warning:**  When playing with audio, beware that the generated sounds can be loud and very high pitched (especially when debugging!). Always reset volume to a minimum before programming the board.

## How to use

> `make ulx3s FIRMWARE=<firmware>` where firmware is a C file (without extension) located in the `./firmware directory`. All files in `firmware` that start with `test_*` can be used to generate a firmware.


For the board: `make ulx3s FIRMWARE=test_menu` (plug the ULX3S first).

For simulation: `make verilator FIRMWARE=test_menu`.

### Using the sdcard

Format the sdcard in FAT32.

### Adding an image

Save the image on the sdcard in a raw pixel format, 256 grayscale 128x128 pixels
(for instance using Gimp, select grayscale mode, export as raw image data).

> To test: save the image in `data/img.raw` to the sdcard and run `make ulx3s FIRMWARE=test_img`

### Adding a music

Encode the tracks as uncompressed wave file, PCM mono **unsigned** 8 bits at 8KHz (use e.g. Audacity, "export", "other uncompressed formats", "raw", "**unsigned** 8 bits PCM").

> To test: save the music on the sdcard as `music.raw` and run `make ulx3s FIRMWARE=test_audio_stream_hrdw`

## Exercises

> **Note:** This section is work in progress. In `main.ice` exercises are identified by `$$if Question_*` which selects either the question of its answer. Later a script will allow to generate the file without the answers.

> **Note:** The firmware to use for streaming audio from the sdcard is `test_audio_stream_hrdw`.

- (`Question_buttons`) Add a memory mapping to buttons, update `test_menu` to use them.
- Add the ULX3S audio output to the SOC (*), memory map it, add `sound.c` to firmware.
Write a `test_audio.c` firmware playing a few tones.
- (`Question_Streaming`) Implement hardware support for audio streaming, and play tracks from the sdcard! (see `test_audio_stream_hrdw` for the firmware).
- (`Question_PWM`) To improve sound quality implement a hardware audio PWM ([what's the idea?](https://electronics.stackexchange.com/questions/239442/audio-using-pwm-what-is-the-principle-behind-it)). Note that I got best results with the PWM between 0 and 1 on the 4 bits audio output (hence using a single bit of the DAC, and considering all 8 sample bits as fractional part).
- Use FAT32 to display file names in menu, see [`void fl_listdirectory(const char *path)`](firmware/fat_io_lib/src/fat_filelib.c).
- Make it sound and look good.
- Use 16 bits audio samples (beware that export will most likely be signed PCM, which will need adjustment hardware side).
- *(Advanced)* Add visual effects to the player, synched with music.

> **(*)** Adding the audio implies modifying the [Makefile](Makefile) to add
`audio` to the list of peripherals (after `...,buttons`),
adding `output uint4 audio_l` and `output uint4 audio_r` to the SOC output list,
mapping these outputs as peripherals in the SOC, and finally exposing these
bindings to the firmware.

## Credits

- Uses the absolutely excellent FAT32 lib by @ultraembedded https://github.com/ultraembedded/fat_io_lib (included as a sumbodule, see README and LICENSE in [firmware/fat_io_lib](firmware/fat_io_lib)).
