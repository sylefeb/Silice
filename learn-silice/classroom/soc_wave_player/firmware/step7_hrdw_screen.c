// @sylefeb 2022-01-10
// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice/

#include "config.h"
#include "std.h"
#include "oled.h"
#include "display.h"
#include "printf.h"

#ifndef HWFBUFFER
#error This firmware needs HWFBUFFER defined
#endif

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

  // gradient background
  for (int i = 0 ; i < 128; ++i) {
    for (int j = 0 ; j < 128; ++j) {
      display_framebuffer()[i + (j << 7)] = i;
    }
  }

  // bouncing text
  int dx = 3;
  int dy = 1;
  int x  = 0;
  int y  = 0;
  while (1) {
    display_set_cursor(x,y);
    printf("Hello world!");
    x += dx;
    if (x > 64) {
      x  = 64;
      dx = -dx;
    } else if (x < 0) {
      x  = 0;
      dx = -dx;
    }
    y += dy;
    if (y > 108) {
      y  = 108;
      y = -dy;
    } else if (y < 0) {
      y  = 0;
      dy = -dy;
    }
  }

}
