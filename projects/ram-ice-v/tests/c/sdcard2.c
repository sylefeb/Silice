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
  for (int k=0;k<4;k++) {
    pause(10000000); 
    *LEDS = 255;
    pause(10000000); 
    *LEDS = 0;
  }

  unsigned char status;

  *LEDS = 1;

  fb_cleanup();

  *LEDS = 2;

  sdcard_init();

  *LEDS = 3;

  while (1) {
    set_cursor(0,0);
  *LEDS = 4;
    status = sdcard_start_sector(1);
  *LEDS = 5;
    printf("---- sdcard content ----\n");
    if (status != 0) {
      printf("sdcard ERROR -- cycle %d\n",time());
    } else {
  *LEDS = 6;
      sdcard_get(1,1); // start token
  *LEDS = 7;
      for (int i=0;i<512;i++) {
        unsigned char by = sdcard_get(8,0);
        putchar("0123456789ABCDEF"[(by >> 4)&15]);
        putchar("0123456789ABCDEF"[(by >> 0)&15]);
        putchar(' ');
        if ((i&15) == 15) { printf("\n"); }
      }
  *LEDS = 8;
      sdcard_get(16,1); // CRC
  *LEDS = 9;
    }
    swap_buffers();
  }

}
