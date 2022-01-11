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

unsigned char data[512];

void main()
{
  // install putchar handler for printf
  f_putchar = display_putchar;

  oled_init();
  oled_fullscreen();
  oled_clear(0);

  display_set_cursor(0,0);
  display_set_front_back_color(255,0);
  printf("init ...\n");
  display_refresh();

  sdcard_init();
  int s = 1;
  while (1) {
    display_set_cursor(0,0);
    sdcard_copy_sector(s,data);
    printf("sector %d\n",s);
    for (int i=0;i<32;i++) {
      unsigned char by = data[i];
      f_putchar("0123456789ABCDEF"[(by >> 4)&15]);
      f_putchar("0123456789ABCDEF"[(by >> 0)&15]);
      f_putchar(' ');
      if ((i&7) == 7) { printf("\n"); }
    }
    display_refresh();
    ++s;
  }

}
