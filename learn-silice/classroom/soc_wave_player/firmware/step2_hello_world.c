// @sylefeb 2022-01-10
// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice/

#include "config.h"
#include "std.h"
#include "oled.h"
#include "display.h"
#include "printf.h"

void main()
{
  // install putchar handler for printf
  f_putchar = display_putchar;
  // init display
  oled_init();
  oled_fullscreen();
  oled_clear(0);
  // print message
  display_set_cursor(0,0);
  display_set_front_back_color(255,0);
  printf("Hello world!\n");
  display_refresh();
}
