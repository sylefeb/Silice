// @sylefeb 2022-01-10

#include "config.h"

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

void dual_putchar(int c)
{
  display_putchar(c);
  *UART = c;
  pause(10000);
}

void main()
{
  // install putchar handler for printf
  f_putchar = display_putchar;

  sdcard_init();

  oled_init();
  oled_fullscreen();
  oled_clear(0);

  display_set_cursor(0,0);
  display_set_front_back_color(255,0);
  printf("Hello world!\n");
  display_refresh();


}
