//#include "../mylibc/mylibc.h"
int time() 
{
   int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles;
}

void pause(int cycles)
{ 
  int tm_start = time();
  while (time() - tm_start < cycles) { }
}

inline int userdata() 
{
  int id;
  asm volatile ("rdtime %0" : "=r"(id));
  return id;
}

volatile unsigned int*  const LEDS = (unsigned int* )0x90000000;
volatile unsigned int*  const PIX  = (unsigned int* )0x90000008;

void main() 
{
  register int o = 0;  
  register int x = 0;  
  register int y = 0;

  register int shift = 0;

  unsigned int ptr = (unsigned int)PIX | (15<<20);

  while (1) {

    if ((userdata()&4) == 0) {  // not writing already
      register unsigned int addr = o + y;
      *(volatile unsigned int*)(ptr | (addr<<4)) = 
          ((255) << 24) | (((x+shift)&255) << 16) | ((255) << 8) | (y);
      ++y;
      if (y == 50) { // 200/4
        o += 50;
        ++x;
        y = 0;
        if (x == 320) {
          o = 0;
          x = 0;
          y = 0;
          shift = shift + 1;
          while ((userdata()&2) == 0) { } // wait vsync
        }
      }
    }
    
  }
}
