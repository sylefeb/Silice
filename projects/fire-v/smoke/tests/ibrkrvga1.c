// MIT license, see LICENSE_MIT in Silice repo root

//#include "../mylibc/mylibc.h"

inline int userdata() 
{
  int id;
  asm volatile ("rdtime %0" : "=r"(id));
  return id;
}

volatile unsigned int*  const PIX  = (unsigned int* )0x9000000C;

void main() 
{
  register int o = 0;  
  register int x = 0;  
  register int y = 0;

  register int shift = 0;

  unsigned int ptr = ((unsigned int)PIX + (8000<<4)/*framebuffer*/) 
                    | (255<<18)/*pixelmask*/;

  while (1) {

    register unsigned int addr = o + x;
    int x0 = ((x)+0+shift) & 15;
    int x1 = ((x)+1+shift) & 15;
    int x2 = ((x)+2+shift) & 15;
    int x3 = ((x)+3+shift) & 15;
    *(volatile unsigned int*)(ptr + (addr<<4)) = 
         (x0 << 28) | (x1 << 24) | (x2 << 20) | (x3 << 16) 
       | (x3 << 12) | (x2 <<  8) | (x1 <<  4) | (x0);
    x += ((userdata()&4) == 0) ? 1 : 0;
    if (x == 40) { 
      o += 40;
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
