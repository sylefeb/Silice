#include "code_blaze.h"

volatile unsigned char* const LEDS        = (unsigned char*)0x90000000;

void main() 
{
  *LEDS=128;
  unsigned char *dst = (unsigned char *)0x0;
  unsigned char *src = code;
  *LEDS=170;
  for (int i=0;i<5512;i++) {
    *dst  = *src;
    ++dst;
    ++src;
  }
  *LEDS=255;
  asm volatile ("jalr x0,0(x0);");
  *LEDS=3;
}
