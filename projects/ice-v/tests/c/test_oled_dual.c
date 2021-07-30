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
  asm volatile ("      \n\
    lui	a0,0x2         \n\
    li	a1,0           \n\
0:  sw	a1,4(a0)       \n\
    addi a1,a1,1       \n\
    lui	 t0,0xa0       \n\
1:  addi t0,t0,-1      \n\
    bne  t0,zero,1b    \n\
    beq  zero,zero,0b  \n\
  ");
  // lui	 t0,0xa0
/*
    while (1) {
      l <<= 1;
      if (l > 8) {
        l = 1;
      }
      *LEDS = l;
      while (i<655360) { i++; }
      i = 0;
    }
*/
#else
    while (1) { }
#endif

  }
}
