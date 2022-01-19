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
int sdcard_file_next_sector;
int sdcard_file_sectors[2048];

int sdcard_readsector_stream(
  long unsigned int start_block,
  unsigned char *buffer,
  long unsigned int sector_count)
{
  if (sdcard_tracker_enabled == 0) {
    return sdcard_readsector(start_block,buffer,sector_count);
  }
  if (sector_count == 0) {
    return 0;
  }
  while (sector_count--) {

    display_set_cursor(0,0);
    if (start_block < 32768) {
      // sector in FAT datastructure, ignore
      printf("sector: %d [FAT]    \n",start_block);
    } else {
      // sector in data, track
      sdcard_file_sectors[sdcard_file_next_sector++] = start_block; // write it down
      printf("sector: %d          \n",start_block);
    }
    display_refresh();
    pause(10000000); // long pause so we can see something
    // read the sector from the sdcard directly
    unsigned char status = sdcard_start_sector(start_block++);
    if (status == 0) {
      sdcard_get(1,1); // start token
      for (int i=0;i<512;i++) {
        // read next byte
        unsigned char by = sdcard_get(8,0);
        // write to buffer
        *(buffer++)         = by;
      }
      sdcard_get(16,1); // CRC
    } else {

    }
  }
  return 1;
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
  sdcard_tracker_enabled  = 0;
  sdcard_file_next_sector = 0;
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

  display_set_cursor(0,0);
  printf("num sectors: %d\n",sdcard_file_next_sector);
  display_refresh();

  pause(20000000); // long pause

  // clear screen and low-level read
  memset(display_framebuffer(),0x00,128*128);
  display_refresh();

  unsigned char *ptr = display_framebuffer();
  for (int i = 0 ; i < sdcard_file_next_sector ; ++i ) {
    unsigned char status = sdcard_start_sector(sdcard_file_sectors[i]);
    if (status == 0) {
      sdcard_get(1,1); // start token
      for (int i=0;i<512;i++) {
        *(ptr++) = sdcard_get(8,0);
      }
      sdcard_get(16,1); // CRC
    }
    display_refresh();
  }

}
