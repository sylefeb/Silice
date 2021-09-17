// Uses GPL code from Adafruit (see in-source comments)
// Otherwise MIT license, see LICENSE_MIT in Silice repo root


#define CMD   (1<< 9)
#define DTA   (1<<10)
#define DELAY (1<<18)

static inline void wait() { asm volatile ("nop; nop; nop; nop; nop; nop; nop;"); }

#define WAIT wait()

typedef unsigned char uint8_t;

void screen_init()
{
  // ================== From Adafruit_ILI9341 -- under GPL license
  #define ILI9341_PWCTR1     0xC0     ///< Power Control 1
  #define ILI9341_PWCTR2     0xC1     ///< Power Control 2
  #define ILI9341_VMCTR1     0xC5     ///< VCOM Control 1
  #define ILI9341_VMCTR2     0xC7     ///< VCOM Control 2
  #define ILI9341_MADCTL     0x36     ///< Memory Access Control
  #define ILI9341_VSCRSADD   0x37     ///< Vertical Scrolling Start Address
  #define ILI9341_PIXFMT     0x3A     ///< COLMOD: Pixel Format Set
  #define ILI9341_FRMCTR1    0xB1     ///< Frame Rate Control (In Normal Mode/Full Colors)
  #define ILI9341_DFUNCTR    0xB6     ///< Display Function Control
  #define ILI9341_GAMMASET   0x26     ///< Gamma Set
  #define ILI9341_DISPON     0x29     ///< Display ON
  #define ILI9341_SLPOUT     0x11     ///< Sleep Out
  #define ILI9341_GMCTRP1    0xE0     ///< Positive Gamma Correction
  #define ILI9341_GMCTRN1    0xE1     ///< Negative Gamma Correction
  uint8_t initcmd[] = {
    0x01, 0,
    0xEF, 3, 0x03, 0x80, 0x02,
    0xCF, 3, 0x00, 0xC1, 0x30,
    0xED, 4, 0x64, 0x03, 0x12, 0x81,
    0xE8, 3, 0x85, 0x00, 0x78,
    0xCB, 5, 0x39, 0x2C, 0x00, 0x34, 0x02,
    0xF7, 1, 0x20,
    0xEA, 2, 0x00, 0x00,
    ILI9341_PWCTR1  , 1, 0x23,             // Power control VRH[5:0]
    ILI9341_PWCTR2  , 1, 0x10,             // Power control SAP[2:0];BT[3:0]
    ILI9341_VMCTR1  , 2, 0x3e, 0x28,       // VCM control
    ILI9341_VMCTR2  , 1, 0x86,             // VCM control2
    ILI9341_MADCTL  , 1, 0x48,             // Memory Access Control
    ILI9341_VSCRSADD, 1, 0x00,             // Vertical scroll zero
    ILI9341_PIXFMT  , 1, 0x66,
    ILI9341_FRMCTR1 , 2, 0x00, 0x18,
    ILI9341_DFUNCTR , 3, 0x08, 0x82, 0x27, // Display Function Control
    0xF2, 1, 0x00,                         // 3Gamma Function Disable
    ILI9341_GAMMASET , 1, 0x01,            // Gamma curve selected
    ILI9341_GMCTRP1 , 15, 0x0F, 0x31, 0x2B, 0x0C, 0x0E, 0x08, // Set Gamma
      0x4E, 0xF1, 0x37, 0x07, 0x10, 0x03, 0x0E, 0x09, 0x00,
    ILI9341_GMCTRN1 , 15, 0x00, 0x0E, 0x14, 0x03, 0x11, 0x07, // Set Gamma
      0x31, 0xC1, 0x48, 0x08, 0x0F, 0x0C, 0x31, 0x36, 0x0F,
    ILI9341_SLPOUT  , 0,                // Exit Sleep
    ILI9341_DISPON  , 0,                // Display on
    0x00                                // End of list
  };
  // =======================================================

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

  const uint8_t *cmd = initcmd;
  while (*cmd) {
    int code   = (int)(*(cmd++)) | CMD;
    screen(code);
    WAIT;
    uint8_t nparams = (uint8_t)(*(cmd++)) & 0x7F;
    while (nparams > 0) {
      int data = (int)(*(cmd++)) | DTA;
      screen(data);
      WAIT;
      nparams --;
    }
    for (register int i=0;i<DELAY;i++) { asm volatile ("nop;"); }
  }

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

static inline void pix(unsigned char r,unsigned char g,unsigned char b)
{
    screen(DTA | r);
    WAIT;
    screen(DTA | g);
    WAIT;
    screen(DTA | b);
    WAIT;
}

void clear(unsigned char c)
{
  for (int v=0;v<240;v++) {
    for (int u=0;u<320;u++) {
      pix(c,c,c);
    }
  }
}
