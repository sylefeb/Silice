// MIT license, see LICENSE_MIT in Silice repo root

#include "../mylibc/mylibc.h"

// cleanup the framebuffers
void fb_cleanup()
{
  for (int i=0;i<(480<<10);i++) {
    *(( FRAMEBUFFER)               + i ) = 8;
    *(( (FRAMEBUFFER + 0x1000000)) + i ) = 8;
  }
}

void main()
{
/*  for (int k=0;k<4;k++) {
    pause(10000000); 
    *LEDS = 255;
    pause(10000000); 
    *LEDS = 0;
  }
*/
  *LEDS = 1;

//  fb_cleanup();

  *LEDS = 2;

  sdcard_init();

  *LEDS = 3;

  while (1) {
    set_cursor(0,0);
    unsigned char data[512];
    sdcard_copy_sector(1,data);
    printf("---- sdcard content, sector 1 ----\n");
    for (int i=0;i<512;i++) {
      unsigned char by = data[i];
      putchar("0123456789ABCDEF"[(by >> 4)&15]);
      putchar("0123456789ABCDEF"[(by >> 0)&15]);
      putchar(' ');
      if ((i&15) == 15) { printf("\n"); }
    }
    swap_buffers(1);
  }

}
