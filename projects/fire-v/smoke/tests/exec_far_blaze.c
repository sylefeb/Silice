// MIT license, see LICENSE_MIT in Silice repo root
// @sylefeb 2020
// https://github.com/sylefeb/Silice

#include "code_blaze.h"

volatile unsigned char* const LEDS        = (unsigned char*)0x90000000;

void main()
{
  *LEDS=128;
  unsigned char *dst = (unsigned char *)0x0000004;
  unsigned char *src = code;
  *LEDS=170;
  for (int i=0;i<1136;i++) {
    *dst = *src;
    ++dst;
    ++src;
  }
  *LEDS=255;
  asm volatile ("li t0,4; jalr x0,0(t0);");
  *LEDS=3;
}
