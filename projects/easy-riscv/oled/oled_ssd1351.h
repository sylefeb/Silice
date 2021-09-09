// MIT license, see LICENSE_MIT in Silice repo root

#define OLED_CMD   (1<< 9)
#define OLED_DTA   (1<<10)
#define DELAY      (1<<18)

static inline void wait() { asm volatile ("nop; nop; nop; nop; nop; nop; nop;"); }

#define WAIT wait()

#define OLED_666 0
#define OLED_565 1

void oled_init_mode(int mode)
{
  register int i;
  // reset high
  oled_rst(0);
  // wait > 100 msec
  for (i=0;i<DELAY;i++) { asm volatile ("nop;"); }
  // reset low
  oled_rst(1);
  // wait > 300us
  for (i=0;i<DELAY;i++) { asm volatile ("nop;"); }
  // reset high
  oled_rst(0);
  // wait > 300 msec
  for (i=0;i<DELAY;i++) { asm volatile ("nop;"); }
  // send screen on
  oled(OLED_CMD | 0xAF);
  // wait > 300 msec
  for (i=0;i<DELAY;i++) { asm volatile ("nop;"); }
  // select auto horiz. increment, RGB mode
  oled(OLED_CMD | 0xA0);
  WAIT;
  if (mode == OLED_666) {
    oled(OLED_DTA | 0xA0);
  } else {
    oled(OLED_DTA | 0x20);
  }
  WAIT;
  // unlock
  oled(OLED_CMD | 0xFD);
  WAIT;
  oled(OLED_DTA | 0xB1);
  WAIT;
  // vertical scroll to zero
  oled(OLED_CMD | 0xA2);
  WAIT;
  oled(OLED_DTA | 0x00);
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
  oled(OLED_CMD | 0x15);
  WAIT;
  oled(OLED_DTA |    0);
  WAIT;
  oled(OLED_DTA |  127);
  WAIT;
  // set row addr
  oled(OLED_CMD | 0x75);
  WAIT;
  oled(OLED_DTA |    0);
  WAIT;
  oled(OLED_DTA |  127);  
  WAIT;
  // initiate write
  oled(OLED_CMD | 0x5c);
  WAIT;
}

static inline void oled_pix(unsigned char r,unsigned char g,unsigned char b)
{
    oled(OLED_DTA | b);
    WAIT;
    oled(OLED_DTA | g);
    WAIT;
    oled(OLED_DTA | r);
    WAIT;
}

static inline void oled_pix_565(unsigned char b5g3,unsigned char g3r5)
{
    oled(OLED_DTA | b5g3);
    WAIT;
    oled(OLED_DTA | g3r5);
    WAIT;
}

void oled_clear(unsigned char c)
{
  for (int v=0;v<128;v++) {
    for (int u=0;u<128;u++) {
      oled_pix(c,c,c);
    }  
  }
}
