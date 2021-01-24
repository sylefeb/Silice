#include "../mylibc/mylibc.h"

void pause(int cycles)
{ 
  long tm_start = time();
  while (time() - tm_start < cycles) { }
}

void main() 
{
  pause(20000000);
    
  // draw screen 
  int offset = 0;
  while (1) { 
    // *(volatile unsigned char*)LEDS = (j&1) ? 0xaa : 0x55;
    *(volatile unsigned char*)LEDS = offset;
    for (int j = 0 ; j < 200 ; j++) {
      for (int i = 0 ; i < 320 ; i++) {
        *(volatile unsigned char*)(FRAMEBUFFER + i + (j << 9)) = (unsigned char)(i+offset);
        pause(10);
      }
    }
    ++offset;
  }

/*
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
*/
}
