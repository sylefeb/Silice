// @sylefeb 2022-01-10
// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice/

#include "config.h"
#include "sdcard.h"
#include "std.h"
#include "oled.h"
#include "display.h"
#include "printf.h"

// include the fat32 library
#include "fat_io_lib/src/fat_filelib.h"

void main()
{
  // install putchar handler for printf
  f_putchar = display_putchar;
  // initialize oled screen
  oled_init();
  oled_fullscreen();
  // clear framebuffer
  memset(display_framebuffer(),0x00,128*128);
  // refresh display (sends framebuffer to screen)
  display_refresh();
  // print a message
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
  // open the image file
  FL_FILE *f = fl_fopen("/img.raw","rb");
  if (f == NULL) {
    printf("img.raw not found.\n");
    display_refresh();
  } else {
    printf("image found.\n");
    display_refresh();
    // read pixels in framebuffer
    fl_fread(display_framebuffer(),1,128*128,f);
    // refresh display to show the image
    display_refresh();
    // close
    fl_fclose(f);
  }
}
