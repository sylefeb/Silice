// @sylefeb 2022-01-10
// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice/

#include "config.h"
#include "std.h"
#include "oled.h"
#include "display.h"
#include "printf.h"

#define N_ITEMS 5

  const char *items[N_ITEMS] = {
    "the sound of silence",
    "sunday bloody sunday",
    "envole-moi",
    "boys don't cry",
    "blouson noir",
  };

void main()
{
  // turn LEDs off
  *LEDS = 0;
  // install putchar handler for printf
  f_putchar = display_putchar;
  // init screen
  oled_init();
  oled_fullscreen();
  oled_clear(0);

  int selected = 0;
  int pulse = 0;

  // enter menu
  while (1) {

    display_set_cursor(0,0);
    // pulsing header
    display_set_front_back_color((pulse+127)&255,pulse);
    pulse += 7;
    printf("    ===== songs =====    \n\n");
    // list items
    for (int i = 0; i < N_ITEMS; ++i) {
      if (i == selected) { // highlight selected
        display_set_front_back_color(0,255);
      } else {
        display_set_front_back_color(255,0);
      }
      printf("%d> %s\n",i,items[i]);
    }
    display_refresh();

    // read buttons and update selection
    if (*BUTTONS & (1<<3)) {
      ++ selected;
    }
    if (*BUTTONS & (1<<4)) {
      -- selected;
    }
    // wrap around
    if (selected < 0) {
      selected = N_ITEMS - 1;
    }
    if (selected >= N_ITEMS) {
      selected = 0;
    }

  }

}
