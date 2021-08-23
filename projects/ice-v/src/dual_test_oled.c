#include "oled.h"

static inline int cpu_id() 
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles&1;
}

void main_oled()
{
  register int o = 0;
  oled_init();
  oled_fullscreen();
  while (1) {
    o+=4;
    for (register int v=0;v<128;v++) {
      for (register int u=0;u<128;u++) {
        oled_pix(u+o,v+o,0);
        WAIT;
      }  
    }
  }
}

void main_leds()
{
  register int l = 1;
  register int i = 0;

  while (1) {
    l <<= 1;
    if (l > 8) {
      l = 1;
    }
    *LEDS = l;
    for (i=0;i<500000;++i) { }
  }
}

void main() 
{

  if (cpu_id() == 1) {

    // core 1 draws screen
    main_oled();

  } else {

    // core 0 blinks LEDS
    main_leds();

  }

}

