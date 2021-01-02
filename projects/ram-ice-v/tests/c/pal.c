#include "../mylibc/mylibc.h"

volatile unsigned int* const PALETTE = (volatile unsigned int*)0x83000000;
// Why 0x83000000 ? We set bit 31 so video_rv32i knows we are using a mapped address, 
// but still write to the last memory bank (0x03000000) where nothing is used.
// The reason is that video_rv32i does not mask addresses and therefore a SDRAM write still
// occurs; we don't want this to end in the framebuffer! 

void pause(int cycles)
{ 
  long tm_start = time();
  while (time() - tm_start < cycles) { }
}

void main() 
{
  // draw screen
  for (int j = 0 ; j < 200 ; j++) {
    for (int i = 0 ; i < 320 ; i++) {
      *(volatile unsigned char*)(i + (j << 9)) = (unsigned char)(i);
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
