// SL 2022-01-10 @sylefeb
//
#pragma once

volatile int* const LEDS     = (int*)0x8004; // 1000000000000100
volatile int* const OLED     = (int*)0x8008; // 1000000000001000
volatile int* const OLED_RST = (int*)0x8010; // 1000000000010000
volatile int* const UART     = (int*)0x8020; // 1000000000100000
volatile int* const SDCARD   = (int*)0x8040; // 1000000001000000
