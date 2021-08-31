// MIT license, see LICENSE_MIT in Silice repo root
#pragma once

volatile int* const LEDS     = (int*)0x80004;
volatile int* const OLED     = (int*)0x80008;
volatile int* const OLED_RST = (int*)0x80010;
volatile int* const SOUND    = (int*)0x80020;
volatile int* const SPIFLASH = (int*)0x80040;
