// MIT license, see LICENSE_MIT in Silice repo root
// @sylefeb 2021
// https://github.com/sylefeb/Silice

#include "config.h"

static inline int core_id()
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles&1;
}

__attribute__((section(".data"))) void vram_fill()
{
  volatile int *VRAM = (volatile int *)0x80000;
  for (int i=0;i<10*200;++i) {
    *(VRAM+i) = (i << 16) | i;
  }
  //*(VRAM+8) = 0xf0f00ff0;
}

void main()
{
  if (core_id()) {

  } else {
    vram_fill();
  }
  while (1) {} // hang
}
