// MIT license, see LICENSE_MIT in Silice repo root
// @sylefeb 2021
// https://github.com/sylefeb/Silice

#include "config.h"
#include "oled.h"

void oled_init_mode(int mode)
{
  register int i;
  // reset high
  *(OLED_RST) = 0;
  // wait > 100 msec
  for (i=0;i<DELAY;i++) { asm volatile ("nop;"); }
  // reset low
  *(OLED_RST) = 1;
  // wait > 300us
  for (i=0;i<DELAY;i++) { asm volatile ("nop;"); }
  // reset high
  *(OLED_RST) = 0;
  // wait > 300 msec
  for (i=0;i<DELAY;i++) { asm volatile ("nop;"); }
  // send screen on
  *(OLED) = OLED_CMD | 0xAF;
  // wait > 300 msec
  for (i=0;i<DELAY;i++) { asm volatile ("nop;"); }
  // select auto horiz. increment, RGB mode
  *(OLED) = OLED_CMD | 0xA0;
  oled_wait();
  if (mode == OLED_666) {
    *(OLED) = OLED_DTA | 0xA0;
  } else {
    *(OLED) = OLED_DTA | 0x20;
  }
  oled_wait();
  // unlock
  *(OLED) = OLED_CMD | 0xFD;
  oled_wait();
  *(OLED) = OLED_DTA | 0xB1;
  oled_wait();
  // vertical scroll to zero
  *(OLED) = OLED_CMD | 0xA2;
  oled_wait();
  *(OLED) = OLED_DTA | 0x00;
  oled_wait();
  // done!
}

void oled_init()
{
  oled_init_mode(OLED_666);
}

void oled_fullscreen()
{
  // set col addr
  *(OLED) = OLED_CMD | 0x15;
  oled_wait();
  *(OLED) = OLED_DTA |    0;
  oled_wait();
  *(OLED) = OLED_DTA |  127;
  oled_wait();
  // set row addr
  *(OLED) = OLED_CMD | 0x75;
  oled_wait();
  *(OLED) = OLED_DTA |    0;
  oled_wait();
  *(OLED) = OLED_DTA |  127;
  oled_wait();
  // initiate write
  *(OLED) = OLED_CMD | 0x5c;
  oled_wait();
}

void oled_clear(unsigned char c)
{
  for (int v=0;v<128;v++) {
    for (int u=0;u<128;u++) {
      oled_pix(c,c,c);
      oled_wait();
    }
  }
}
