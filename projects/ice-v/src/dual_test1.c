// MIT license, see LICENSE_MIT in Silice repo root

#include "config.h"

inline int core_id()
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles;
}

void main()
{

  if (core_id()&1) {
    while (1) {
      *LEDS = 2;
    }
  } else {
    while (1) {
      *LEDS = 16;
    }
  }

}
