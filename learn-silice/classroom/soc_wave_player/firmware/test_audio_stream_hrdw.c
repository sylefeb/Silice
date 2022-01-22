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
  display_set_cursor(0,0);

  // open the file
  FL_FILE *f = fl_fopen("/music.raw","rb");
  if (f == NULL) {
    printf("file not found.\n");
    display_refresh();
  } else {
    printf("playing.       \n");
    display_refresh();
    // plays the entire file
    int max_cycles = 0;
    while (1) {
      // read directly in hardware buffer
      int *addr = (int*)(*AUDIO);
      // (use 512 bytes reads to avoid extra copies inside fat_io_lib)
      int sz = fl_fread(addr,1,512,f);
      if (sz < 512) break; // reached end of file
      // wait for buffer swap
      int start_tm = rdcycle();
      while (addr == (int*)(*AUDIO)) { }
      int elapsed = rdcycle() - start_tm;
      if (elapsed > max_cycles) {
        max_cycles = elapsed;
      }
    }
    // close
    fl_fclose(f);

    printf("max cycles: %d  \n",max_cycles);
    display_refresh();

  }

}
