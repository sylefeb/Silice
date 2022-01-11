// @sylefeb 2022-01-10

#include "config.h"
#include "std.c"
#include "oled.h"
#include "printf.c"
#include "mul.c"
#include "sdcard.c"
#include "display.c"

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
  *LEDS = 4;

  // install putchar handler for printf
  f_putchar = display_putchar;

  sdcard_init();

  oled_init();
  oled_fullscreen();
  oled_clear(0);

  int selected = 0;
  int pulse = 0;

  while (1) {

    display_set_cursor(0,0);
    display_set_front_back_color((pulse+127)&255,pulse);
    ++ pulse;
    printf("    ===== songs =====    \n\n");
    for (int i = 0; i < N_ITEMS; ++i) {
      if (i == selected) {
        display_set_front_back_color(0,255);
      } else {
        display_set_front_back_color(255,0);
      }
      printf("%d> %s\n",i,items[i]);
    }
    display_refresh();

    // TODO: replace by button presses to go down/up the list
    ++ selected;
    if (selected == N_ITEMS) {
      selected = 0;
    }

  }

}
