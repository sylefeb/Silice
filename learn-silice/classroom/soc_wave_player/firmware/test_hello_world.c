// @sylefeb 2022-01-10

#include "config.h"
#include "std.c"
#include "oled.h"
#include "printf.c"
#include "mul.c"
#include "sdcard.c"
#include "display.c"

void main()
{
  *LEDS = 4;

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
