#include "../mylibc/mylibc.h"

void pause(int cycles)
{ 
  long tm_start = time();
  while (time() - tm_start < cycles) { }
}

void main() 
{
  *LEDS = 5;
  
  // draw screen
  for (int j = 0 ; j < 200 ; j++) {
    for (int i = 0 ; i < 320 ; i++) {
      *(volatile unsigned char*)(FRAMEBUFFER + i + (j << 9)) = (unsigned char)(i);
      pause(0);
    }
  }
  
  // rotate palette
  int offset = 0;
  while (1) {
    for (int p = 0 ; p < 256 ; p++) {
      unsigned char clr = p + offset;
      *(PALETTE + p) = clr | (clr << 8) | (clr << 16);
    }
    ++offset;
    pause(1000000); // 0.02 sec @50 MHz
  }

}
