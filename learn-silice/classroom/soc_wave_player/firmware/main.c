// @sylefeb 2022-01-10

volatile int* const LEDS     = (int*)0x2004;
volatile int* const OLED     = (int*)0x2008;
volatile int* const OLED_RST = (int*)0x2010;

#include "oled.h"

static inline unsigned int rdcycle()
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles;
}

static inline void sleep(int ncycles)
{
  unsigned int start = rdcycle();
  while ( rdcycle() - start < ncycles ) { }
}

void main()
{
	int i = 0;

  oled_init();
  oled_fullscreen();
  oled_clear(63);

	while (1) {
		*LEDS = i;
		++i;
    sleep(1000000);
	}
}
