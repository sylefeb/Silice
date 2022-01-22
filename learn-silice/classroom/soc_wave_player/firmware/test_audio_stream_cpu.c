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

unsigned char buffer[1024]; // 512 x2
int           last_tm;
int           max_elapsed;
int           buffer_swap;
int           do_streaming;
int           current_sample;

void callback()
{
  int elapsed = rdcycle() - last_tm; // NOTE: beware of 2^32 wrap around on rdcycle
  if (elapsed > 3125) {
    // if (elapsed > max_elapsed) { max_elapsed = elapsed; }
    if (current_sample < 1024 && do_streaming) {
      // send next audio sample
      unsigned char smpl = buffer[current_sample++];
      *AUDIO = smpl;
      *LEDS  = smpl;
    }
    last_tm = rdcycle();
  }
}

void callback_empty() { }

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
    // install callback
    sdcard_while_loading_callback = callback;
    max_elapsed  = 0;
    // read data (use 512 bytes reads to avoid extra copies inside fat_io_lib)
    buffer_swap  = 0;
    do_streaming = 0;
    last_tm      = rdcycle();
    // plays the entire file
    while (1) {
      // read in buffer_swap (other is ready for streaming)
      int sz = fl_fread(buffer + (buffer_swap ? 512 : 0),1,512,f);
      if (sz < 512) break;
      // start streaming after first read
      do_streaming   = 1;
      // finish audio
      while (current_sample < 512 + (buffer_swap ? 0 : 512)) {
         callback();
      }
      // swap buffer
      current_sample = buffer_swap ? 512 : 0;
      buffer_swap    = 1-buffer_swap;
    }
    sdcard_while_loading_callback = callback_empty;
    // close
    fl_fclose(f);
  }

  display_set_cursor(0,0);
  display_set_front_back_color(255,0);
  printf("max_elapsed: %d    \n",max_elapsed);
  display_refresh();

}
