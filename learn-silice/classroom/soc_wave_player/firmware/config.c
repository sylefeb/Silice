// @sylefeb 2022-01-10
// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice/

volatile int* const LEDS     = (int*)0x10004; // 10000000000000100
volatile int* const OLED     = (int*)0x10008; // 10000000000001000
volatile int* const OLED_RST = (int*)0x10010; // 10000000000010000
volatile int* const UART     = (int*)0x10020; // 10000000000100000
volatile int* const SDCARD   = (int*)0x10080; // 10000000010000000
                                              // 10000000100000000
volatile int* const AUDIO    = (int*)0x10200; // 10000001000000000
