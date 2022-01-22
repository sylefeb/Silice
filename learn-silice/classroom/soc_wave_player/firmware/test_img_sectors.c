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

int sdcard_tracker_enabled;

int sdcard_readsector_stream(
  long unsigned int start_block,
  unsigned char *buffer,
  long unsigned int sector_count)
{
  if (sdcard_tracker_enabled == 1) {
    // when the tracker is enabled we capture the call
    while (sector_count-- > 0) { // read sectors one by one
      // display its number
      display_set_cursor(0,0);
      printf("sector: %d          \n",start_block);
      display_refresh();
      pause(10000000); // long pause so we can see something
      // read sector
      sdcard_readsector(start_block,buffer,1);
      start_block++; buffer+=512;
    }
  } else {
    return sdcard_readsector(start_block,buffer,sector_count);
  }
}

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
  sdcard_tracker_enabled  = 0; // tracker disabled
  sdcard_init();
  // initialise File IO Library
  fl_init();
  // attach media access functions to library
  while (fl_attach_media(sdcard_readsector_stream, sdcard_writesector) != FAT_INIT_OK) {
    // try again, we need this
  }
  printf("done.\n");

  // open the file
  FL_FILE *f = fl_fopen("/img.raw","rb");
  if (f == NULL) {
    printf("img.raw not found.\n");
    display_refresh();
  } else {
    printf("image found.\n");
    display_refresh();
    // read pixels in framebuffer
    sdcard_tracker_enabled = 1; // start tracking sectors
    fl_fread(display_framebuffer(),1,128*128,f);
    sdcard_tracker_enabled = 0; // stop tracking sectors
    display_refresh();
    // close
    fl_fclose(f);
  }

}
