// MIT license, see LICENSE_MIT in Silice repo root
// @sylefeb 2021
// https://github.com/sylefeb/Silice

#include "config.h"

void main()
{
  volatile int i = 0;

  *((volatile unsigned char *)(LEDS)+1) = 0xba;
  *((volatile unsigned short*)(LEDS)+1) = 0xbeef;

  unsigned char  t_c = *((volatile unsigned char *)(LEDS)+1);
  unsigned short t_s = *((volatile unsigned short*)(LEDS)+1);

  int l = 1;

  while (1) {
    l <<= 1;
    if (l > 8) {
      l = 1;
    }
    *LEDS = l;
    // for (i=0;i<655360;i++) { asm volatile ("nop;"); }
    for (i=0;i<655360;i++) {  }
    // for (i=0;i<32;i++) {  }
  }

}
