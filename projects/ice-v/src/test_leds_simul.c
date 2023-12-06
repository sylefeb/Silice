// MIT license, see LICENSE_MIT in Silice repo root
// @sylefeb 2021
// https://github.com/sylefeb/Silice

#include "config.h"

void f_putchar(int) {}

void main()
{
  volatile int i = 0;

  *LEDS = 0x0f;

  int l = 1;
  while (1) {

    l <<= 1;
    if (l > 8) {
      l = 1;
    }

    *LEDS = l;

  }

}
