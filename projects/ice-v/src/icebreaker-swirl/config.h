// MIT license, see LICENSE_MIT in Silice repo root
// @sylefeb 2020
#pragma once

volatile int* const LEDS     = (int*)0x2004;
volatile int* const OLED     = (int*)0x2008;
volatile int* const OLED_RST = (int*)0x2010;
volatile int* const SOUND    = (int*)0x2020;
volatile int* const SPIFLASH = (int*)0x2040;
