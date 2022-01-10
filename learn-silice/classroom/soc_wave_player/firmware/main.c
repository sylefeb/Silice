// @sylefeb 2022-01-10

volatile int* const LEDS     = (int*)0x2004; // 0010000000000100
volatile int* const OLED     = (int*)0x2008; // 0010000000001000
volatile int* const OLED_RST = (int*)0x2010; // 0010000000010000
volatile int* const UART     = (int*)0x2020; // 0010000000100000

static inline unsigned int rdcycle()
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles;
}

static inline void pause(int ncycles)
{
  unsigned int start = rdcycle();
  while ( rdcycle() - start < ncycles ) { }
}

#include "oled.h"
#include "printf.c"
#include "mul.c"
// #include "sdcard.c"

void main()
{
	//int i = 0;

  //oled_init();
  //oled_fullscreen();

  while (1) {
    printf("Hello world!\n");
  }

  // sdcard_init();

/*
	while (1) {
		*LEDS = i;
		++i;
    oled_clear(i);
    pause(1000000);
	}
*/
}
