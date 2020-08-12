# SDcard test, using an OLED/LCD small screen.

## Content:

- oled_sdcard_test.ice Allows to explore sectors, outputing the hex content on the screen. On the ULX3S the fire buttons allow to go to previous/next sectors.

- oled_sdcard_imgview.ice Displays a palleted image stored onto the SDcard. The input image (test.tga, 256 color palette) is turned into a raw file (raw.img) during compilation. This file should be written to the SDcard at the start offset (0x00000000). For instance; under Windows this can be done directly using [Win32DiskImager](https://sourceforge.net/projects/win32diskimager/files/latest/download).

Tested on the ULX3S, with a 240x320 OLED screen (ST7789 driver) from Waveshare, plugged into the ULXS OLED pins).

## Work in progress

This has been tested only on a couple SDcards. Works only with SDHC/SDXC cards (partial protocol implementation). Very slow (always uses initialization frequency for now).

## Credits

The test image is a crop from Wikipedia: https://en.wikipedia.org/wiki/SD_card
