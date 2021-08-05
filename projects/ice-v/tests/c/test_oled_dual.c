#include "oled.h"

static inline int cpu_id() 
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles&1;
}

void main() 
{
  register int o = 0;
  register int l = 1;
  register int i = 0;

  if (cpu_id() == 0) {

    // core 1 blinks screen
    oled_init();
    oled_fullscreen();
    while (1) {
      o+=4;
      for (int v=0;v<128;v++) {
        for (int u=0;u<128;u++) {
          oled_pix(u+o,v+o,0);
        }  
      }
    }

  } else {

    // core 0 blinks LEDS
    while (1) {
      l <<= 1;
      if (l > 8) {
        l = 1;
      }
      *LEDS = l;
      for (i=0;i<500000;++i) { }
    }
  }

}

