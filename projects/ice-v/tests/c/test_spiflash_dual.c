#include "oled.h"

#include "spiflash.c"

volatile int* const SOUND = (int*)0x2020;

static inline unsigned int time() 
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles>>1;
}

static inline unsigned int cpu_id() 
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles&1;
}

void main_sound()
{
  unsigned int cy_last = time();
  unsigned int cy;

  int s   = 0;
  int dir = 1;

  spiflash_init();
  spiflash_read_begin(0);	
  while (1) {
    cy = time();
    if (cy < cy_last) { cy_last = cy; } // counter may wrap around
    if (cy > cy_last + 1407) {
      *SOUND  = spiflash_read_next();
      cy_last = cy;
      s += dir;
      if (s > 127 || s < -127) {
        dir = -dir;
      }
    }
  }
}

void main_oled()
{
  int o = 0;
  oled_init();
  oled_fullscreen();    
  while (1) {
    o += 4;
    for (int v=0;v<128;v++) {
      for (int u=0;u<128;u++) {
        oled_pix(u+o,v,0);
      }
    }	
  }    
}

void main()
{
  if (cpu_id() == 1) {

    main_sound();

	} else {

    main_oled();

  }

}
