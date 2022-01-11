// @sylefeb 2022-01-10

#include "config.h"
#include "std.c"
#include "oled.h"
#include "printf.c"
#include "mul.c"
#include "sdcard.c"
#include "display.c"

#include "fat_io_lib/src/fat_filelib.h"

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
  printf("FAT working?\n");
  display_refresh();

  // Initialise File IO Library
  fl_init();
  // Attach media access functions to library
  while (fl_attach_media(sdcard_readsector, sdcard_writesector) != FAT_INIT_OK) {
    // try again, we need this
  }
  // List the root directory
  fl_listdirectory("/");

}
