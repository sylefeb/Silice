#include "oled.h"

inline int cpu_id() 
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles>>31;
}

void main() 
{
  volatile int i = 0;
  if (cpu_id()) {
    /*
    oled_init();
    oled_fullscreen();
    int b = 0;
    while (1) {
      b+=7;
      oled_clear(b);
    }
    */
    while (1) {}
  } else {
    int l = 1;
    while (1) {
      l <<= 1;
      if (l > 8) {
        l = 1;
      }
      *LEDS = l;    
      for (i=0;i<655360;i++) { }
    }    
  }
}
