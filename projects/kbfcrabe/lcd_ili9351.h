// Otherwise MIT license, see LICENSE_MIT in Silice repo root

#define CMD   (1<< 9)
#define DTA   (1<<10)
#define DELAY (1<<18)

static inline void wait() { asm volatile ("nop; nop;"); }

#define WAIT wait()

void screen_init()
{
  int initseq[] = {
    0x01,                             // Soft reset
    0xC0, 0x100 | 0x23,               // Power control
    0xC1, 0x100 | 0x10,               //
    0xC5, 0x100 | 0x3e, 0x100 | 0x28, // VCM control
    0xC7, 0x100 | 0x06,               //
    0x36, 0x100 | 0x48,               // MADCTL
    0x37, 0x100 | 0x00,               // V scroll
    0x51, 0x100 | 0xFF,               // brightness
    0x3A, 0x100 | 0x66,               // pixel format, 6-6-6
    0x11,                             // sleep out
    0x29,                             // display on
    0x00
  };

  // reset high
  screen_rst(1);
  // wait > 100 msec
  for (register int i=0;i<DELAY;i++) { asm volatile ("nop;"); }
  // reset low
  screen_rst(0);
  // wait > 300us
  for (register int i=0;i<DELAY;i++) { asm volatile ("nop;"); }
  // reset high
  screen_rst(1);
  for (register int i=0;i<DELAY;i++) { asm volatile ("nop;"); }
  // send init sequence
  const int *ptr = initseq;
  while (*ptr) {
    if (((*ptr) & 0x100) == 0) {
      for (register int i=0;i<DELAY;i++) { asm volatile ("nop;"); }
      int code = (int)(*(ptr++)) | CMD;
      screen(code);
    } else {
      WAIT;
      int data = ((int)(*(ptr++)) & ~0x100) | DTA;
      screen(data);
    }
  }
  WAIT;
  // done!
}

void screen_fullscreen()
{
  // set col addr
  screen(CMD | 0x2A);
  WAIT;
  screen(DTA |    0);
  WAIT;
  screen(DTA |    0);
  WAIT;
  screen(DTA |    0);
  WAIT;
  screen(DTA | 0xF0); // 240
  WAIT;
  // set row addr
  screen(CMD | 0x2B);
  WAIT;
  screen(DTA |    0);
  WAIT;
  screen(DTA |    0);
  WAIT;
  screen(DTA | 0x01); // 0x140 == 320
  WAIT;
  screen(DTA | 0x40);
  WAIT;
  // initiate write
  screen(CMD | 0x2c);
  WAIT;
}

void screen_rect(int left,int right,int bottom,int top)
{
  // set col addr
  screen(CMD | 0x2A);
  WAIT;
  screen(DTA | (left>>8));
  WAIT;
  screen(DTA | (left&255));
  WAIT;
  screen(DTA | (right>>8));
  WAIT;
  screen(DTA | (right&255));
  WAIT;
  // set row addr
  screen(CMD | 0x2B);
  WAIT;
  screen(DTA | (bottom>>8));
  WAIT;
  screen(DTA | (bottom&255));
  WAIT;
  screen(DTA | (top>>8));
  WAIT;
  screen(DTA | (top&255));
  WAIT;
  // initiate write
  screen(CMD | 0x2c);
  WAIT;
}

static inline void pix(unsigned char r,unsigned char g,unsigned char b)
{
    screen(DTA | r);
    WAIT;
    screen(DTA | g);
    WAIT;
    screen(DTA | b);
    // WAIT;
}

void clear(unsigned char c)
{
  for (int v=0;v<240;v++) {
    for (int u=0;u<320;u++) {
      pix(c,c,c);
    }
  }
}
