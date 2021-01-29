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
      register unsigned int addr = o + x;
      int x0 = ((x<<2)+0+shift) & 255;
      int x1 = ((x<<2)+1+shift) & 255;
      int x2 = ((x<<2)+2+shift) & 255;
      int x3 = ((x<<2)+3+shift) & 255;
      *(volatile unsigned int*)(ptr | (addr<<4)) = 
          (x3 << 24) | (x2 << 16) | (x1 << 8) | (x0);
      ++x;
      if (x == 80) { // 320/4
        o += 80;
        x = 0;
        ++y;
        if (y == 200) {
          o = 0;
          x = 0;
          y = 0;
          shift = shift + 1;
        }
      }
    }
    
  }
}
