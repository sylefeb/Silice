// MIT license, see LICENSE_MIT in Silice repo root

#include "config.h"

inline int cpu_id() 
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles;
}

void main() 
{
  volatile int i = 0;

  *LEDS = 0x0f;
  
  int l = 1;
  
  if (cpu_id()&1) {  
    while (1) {}
  }

  while (1) {
    
      l <<= 1;
      if (l > 8) {
        l = 1;
      }
      
      *LEDS = l;    
      
      for (i=0;i<655350;i++) { }
      // for (i=0;i<7;i++) { }
  }

  //} else {
  //  while (1) {}
  //}
}
