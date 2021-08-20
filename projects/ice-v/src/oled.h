#include "config.h"

#define OLED_CMD   (1<< 9)
#define OLED_DTA   (1<<10)
#define DELAY      (1<<18)

// OLED 4x version ( < 70 MHz)
// static inline void wait() { asm volatile ("nop; nop; nop; "); } // 60,70 MHz
// OLED 8x version (>= 70 MHz)
static inline void wait() { asm volatile ("nop; nop; nop; nop; nop; nop; nop;"); }

#define WAIT wait()

void oled_init()
{
  register int i;
  // reset high
  *(OLED_RST) = 0;
  // wait > 100 msec
  for (i=0;i<DELAY;i++) {  }
  // reset low
  *(OLED_RST) = 1;
  // wait > 300us
  for (i=0;i<DELAY;i++) {  }
  // reset high
  *(OLED_RST) = 0;
  // wait > 300 msec
  for (i=0;i<DELAY;i++) {  }
  // send screen on
  *(OLED) = OLED_CMD | 0xAF;
  // wait > 300 msec
  for (i=0;i<DELAY;i++) {  }
  
  // select auto horiz. increment, 666 RGB 
  *(OLED) = OLED_CMD | 0xA0;
  WAIT;
  *(OLED) = OLED_DTA | 0xA0;
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
    // WAIT;
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
