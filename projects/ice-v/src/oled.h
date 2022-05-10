// MIT license, see LICENSE_MIT in Silice repo root
// @sylefeb 2021
// https://github.com/sylefeb/Silice

#include "config.h"

#define OLED_CMD   (1<< 9)
#define OLED_DTA   (1<<10)

#if defined(ICESTICK_CONVEYOR) | defined(ICEBREAKER_SWIRL)
#define DELAY      (1<<18)
static inline void wait() { for (int i=0;i<16;++i) { asm volatile ("nop;"); } }
#else
#define DELAY      (1<<18)
static inline void wait() { asm volatile ("nop; nop; nop; nop; nop; nop; nop;"); }
#endif

#define WAIT wait()

#define OLED_666 0
#define OLED_565 1

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
  WAIT;
  if (mode == OLED_666) {
    *(OLED) = OLED_DTA | 0xA0;
  } else {
    *(OLED) = OLED_DTA | 0x20;
  }
  WAIT;
  // unlock
  *(OLED) = OLED_CMD | 0xFD;
  WAIT;
  *(OLED) = OLED_DTA | 0xB1;
  WAIT;
  // vertical scroll to zero
  *(OLED) = OLED_CMD | 0xA2;
  WAIT;
  *(OLED) = OLED_DTA | 0x00;
  WAIT;
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
  WAIT;
  *(OLED) = OLED_DTA |    0;
  WAIT;
  *(OLED) = OLED_DTA |  127;
  WAIT;
  // set row addr
  *(OLED) = OLED_CMD | 0x75;
  WAIT;
  *(OLED) = OLED_DTA |    0;
  WAIT;
  *(OLED) = OLED_DTA |  127;
  WAIT;
  // initiate write
  *(OLED) = OLED_CMD | 0x5c;
  WAIT;
}

static inline void oled_pix(unsigned char r,unsigned char g,unsigned char b)
{
    *(OLED) = OLED_DTA | b;
    WAIT;
    *(OLED) = OLED_DTA | g;
    WAIT;
    *(OLED) = OLED_DTA | r;
}

static inline void oled_pix_565(unsigned char b5g3,unsigned char g3r5)
{
    *(OLED) = OLED_DTA | b5g3;
    WAIT;
    *(OLED) = OLED_DTA | g3r5;
}

static inline void oled_comp(unsigned char c)
{
    *(OLED) = OLED_DTA | c;
}

void oled_clear(unsigned char c)
{
  for (int v=0;v<128;v++) {
    for (int u=0;u<128;u++) {
      oled_pix(c,c,c);
      WAIT;
    }
  }
}
