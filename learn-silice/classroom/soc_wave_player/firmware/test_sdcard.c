// @sylefeb 2022-01-10
// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice/

#include "config.h"
#include "sdcard.h"
#include "std.h"
#include "oled.h"
#include "display.h"
#include "printf.h"

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
  int s = 0;
  while (1) {
    display_set_cursor(0,0);
    sdcard_read_sector(s,data);
    printf("sector %d\n",s);
    for (int i=0;i<96;i++) {
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
