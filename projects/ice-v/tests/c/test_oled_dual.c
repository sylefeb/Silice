#include "oled.h"

static inline int cpu_id() 
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles;
}

void main() 
{
  register int b = 0;
  register int l = 1;
  register int i = 0;

  if (cpu_id()&1) {
    
    // core 1 blinks screen
    oled_init();
    oled_fullscreen();
    while (1) {
      b+=7;
      oled_clear(b);
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
