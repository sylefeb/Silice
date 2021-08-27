// MIT license, see LICENSE_MIT in Silice repo root

#include "../mylibc/mylibc.h"

void pause(int cycles)
{ 
  long tm_start = time();
  while (time() - tm_start < cycles) { }
}

void main() 
{
  /*while (1)*/ {
    for (int i = 0 ; i < 320<<9 ; i++) {
      *(FRAMEBUFFER + i) = i;
    }
    set_cursor(0,0);
    printf("Hello how are you?");
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
