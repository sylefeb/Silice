#include "oled.h"

static inline int time_cpu_id() 
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

  if (time_cpu_id()&1) {
#if 0
    oled_init();
    oled_fullscreen();
    while (1) {
      b+=7;
      oled_clear(b);
    }
#else
    while (1) { }
#endif
  } else {

#if 1
    while (1) {
      l <<= 1;
      if (l > 8) {
        l = 1;
      }
      *LEDS = l;
      while (i<655360) { i++; }
      i = 0;
    }
#else
    while (1) { }
#endif

  }
}
