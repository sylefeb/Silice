// @sylefeb 2022-01-10
// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice/

#include "config.h"
#include "sdcard.h"
#include "std.h"
#include "oled.h"
#include "display.h"
#include "printf.h"

#include "fat_io_lib/src/fat_filelib.h"

void main()
{
  // install putchar handler for printf
  f_putchar = display_putchar;

  oled_init();
  oled_fullscreen();

  memset(display_framebuffer(),0x00,128*128);
  display_refresh();

  display_set_cursor(0,0);
  display_set_front_back_color(255,0);
  printf("init ... ");
  display_refresh();

  // init sdcard
  sdcard_init();
  // initialise File IO Library
  fl_init();
  // attach media access functions to library
  while (fl_attach_media(sdcard_readsector, sdcard_writesector) != FAT_INIT_OK) {
    // try again, we need this
  }
  printf("done.\n");
  display_refresh();

  // playing the track
  // -> open the file
  FL_FILE *f = fl_fopen("/music.raw","rb");
  if (f == NULL) {
    // error, no file
    printf("file not found.\n");
    display_refresh();
  } else {
    display_set_front_back_color(0,255);
    printf("music file found.\n");
    display_refresh();
    display_set_front_back_color(255,0);
    printf("playing ... ");
    display_refresh();
    int leds = 1;
    int dir  = 0;
    // plays the entire file
    while (1) {
      // read directly in hardware buffer
      int *addr = (int*)(*AUDIO);
      // (use 512 bytes reads to avoid extra copies inside fat_io_lib)
      int sz = fl_fread(addr,1,512,f);
      if (sz < 512) break; // reached end of file
      // wait for buffer swap
      while (addr == (int*)(*AUDIO)) { }
      // light show!
      if (leds == 128 || leds == 1) { dir = 1-dir; }
      if (dir) {
        leds = leds << 1;
      } else {
        leds = leds >> 1;
      }
      *LEDS = leds;
    }
    // close
    fl_fclose(f);
  }

}
