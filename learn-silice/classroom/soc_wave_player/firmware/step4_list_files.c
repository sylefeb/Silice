// @sylefeb 2022-01-10
// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice/

#include "config.h"
#include "std.h"
#include "oled.h"
#include "display.h"
#include "printf.h"
#include "sdcard.h"

// include the fat32 library
#include "fat_io_lib/src/fat_filelib.h"

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
  // init sdcard
  sdcard_init();
  // initialise File IO Library
  fl_init();
  // attach media access functions to library
  while (fl_attach_media(sdcard_readsector, sdcard_writesector) != FAT_INIT_OK) {
    // keep trying, we need this
  }
  // header
  display_set_cursor(0,0);
  display_set_front_back_color(0,255);
  printf("    ===== files =====    \n\n");
  display_refresh();
  display_set_front_back_color(255,0);
  // list files (see fl_listdirectory if at_io_lib/src/fat_filelib.c)
  const char *path = "/";
  FL_DIR dirstat;
  // FL_LOCK(&_fs);
  if (fl_opendir(path, &dirstat)) {
    struct fs_dir_ent dirent;
    while (fl_readdir(&dirstat, &dirent) == 0) {
      if (!dirent.is_dir) {
        // print file name
        printf("%s [%d bytes]\n", dirent.filename, dirent.size);
      }
    }
    fl_closedir(&dirstat);
  }
  // FL_UNLOCK(&_fs);
  display_refresh();

}
