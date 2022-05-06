// MIT license, see LICENSE_MIT in Silice repo root
// @sylefeb 2021
// https://github.com/sylefeb/Silice

#include "config.h"

volatile int* const ROM = (int*)0x100000;

void main()
{
  *LEDS = 0x0f;
	*ROM  = 0x123456;

  while (1) {}
}
