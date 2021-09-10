// MIT license, see LICENSE_MIT in Silice repo root

#define OLED_CMD   (1<< 9)
#define OLED_DTA   (1<<10)
#define DELAY      (1<<18)

static inline void wait() { asm volatile ("nop; nop; nop; nop; nop; nop; nop;"); }

#define WAIT wait()

void oled_init()
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
  // software reset
	oled(OLED_CMD | 0x01);
  for (i=0;i<DELAY;i++) { asm volatile ("nop;"); }
  // sleep out
	oled(OLED_CMD | 0x11);
  for (i=0;i<DELAY;i++) { asm volatile ("nop;"); }
  // colmod
	oled(OLED_CMD | 0x3A);
	WAIT;
	oled(OLED_DTA | 0x66);
  for (i=0;i<DELAY;i++) { asm volatile ("nop;"); }
	// madctl
	oled(OLED_CMD | 0x36);
	WAIT;
	oled(OLED_DTA | 0x00);
  for (i=0;i<DELAY;i++) { asm volatile ("nop;"); }
  // invon
	oled(OLED_CMD | 0x21);
	for (i=0;i<DELAY;i++) { asm volatile ("nop;"); }
	// noron
	oled(OLED_CMD | 0x13);
	for (i=0;i<DELAY;i++) { asm volatile ("nop;"); }
	// brightness
	oled(OLED_CMD | 0x51);
	WAIT;
	oled(OLED_DTA | 0xFF);
	WAIT;
  // display on
	oled(OLED_CMD | 0x29);
	for (i=0;i<DELAY;i++) { asm volatile ("nop;"); }
  // done!
}

void oled_fullscreen()
{
  // set col addr
  oled(OLED_CMD | 0x2A);
  WAIT;
  oled(OLED_DTA |    0);
  WAIT;
  oled(OLED_DTA |    0);
  WAIT;
  oled(OLED_DTA |    0);
  WAIT;
  oled(OLED_DTA | 0xF0); // 240
  WAIT;
  // set row addr
  oled(OLED_CMD | 0x2B);
  WAIT;
  oled(OLED_DTA |    0);
  WAIT;
  oled(OLED_DTA |    0);
  WAIT;
  oled(OLED_DTA | 0x01); // 0x140 == 320
  WAIT;
  oled(OLED_DTA | 0x40);  
  WAIT;
  // initiate write
  oled(OLED_CMD | 0x2c);
  WAIT;
}

static inline void oled_pix(unsigned char r,unsigned char g,unsigned char b)
{
    oled(OLED_DTA | r);
    WAIT;
    oled(OLED_DTA | g);
    WAIT;
    oled(OLED_DTA | b);
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
