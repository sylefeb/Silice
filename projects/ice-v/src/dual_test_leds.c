// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice
// @sylefeb 2021

#include "config.h"

static inline int core_id()
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles&1;
}

void main()
{
  volatile int i = 0;

  *LEDS = 0x0f;

  register int l = 1;

  if (core_id() == 1) {

		while (1) {
			l <<= 1;
			if (l > 8) {
				l = 1;
			}
			*LEDS = l;
			for (i=0;i<100000;i++) { }
		}

	} else {

		while (1) { }

	}
}
