// @sylefeb 2022-01-10

volatile int* const LEDS     = (int*)0x8004; // 1000000000000100
volatile int* const OLED     = (int*)0x8008; // 1000000000001000
volatile int* const OLED_RST = (int*)0x8010; // 1000000000010000
volatile int* const UART     = (int*)0x8020; // 1000000000100000
volatile int* const SDCARD   = (int*)0x8020; // 1000000001000000

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
#include "sdcard.c"
#include "display.c"

void uart_putchar(int c)
{
  *UART = c;
  pause(10000);
}

void main()
{
  // install putchar handler for printf
  f_putchar = uart_putchar;

	//int i = 0;

  oled_init();
  oled_fullscreen();

  display_set_cursor(1,0);
  display_putchar('A');
  display_refresh();

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
