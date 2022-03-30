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
  int frame = 0;
  volatile int *VRAM = (volatile int *)0x80000;
  while (1) {
    for (int i=0;i<10*200;++i) {
      int f = frame + i;
      *(VRAM+i) = (f << 16) | f;
    }
    ++ frame;
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
