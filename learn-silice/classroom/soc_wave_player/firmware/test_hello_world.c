// @sylefeb 2022-01-10
// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice/

#include "config.h"
#include "sdcard.h"
#include "std.h"
#include "oled.h"
#include "display.h"
#include "printf.h"

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
