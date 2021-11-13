// @sylefeb 2020
// https://github.com/sylefeb/Silice
// MIT license, see LICENSE_MIT in Silice repo root

//#include "../mylibc/mylibc.h"
long time()
{
   int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles;
}

void pause(int cycles)
{
  long tm_start = time();
  while (time() - tm_start < cycles) { }
}

void main()
{
  while (1) {
    *(volatile unsigned char*)0x90000000 = 0xff;
    pause(2500000);
    //pause(1000);
    *(volatile unsigned char*)0x90000000 = 0x00;
    pause(2500000);
    //pause(1000);
  }
}
