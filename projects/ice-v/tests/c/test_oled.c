int* const LEDS = (int*)0x1000;

#include "oled.h"

void main() 
{
  *(LEDS) = 5;

  oled_init();
  oled_fullscreen();
  int b = 0;
  while (1) {
    b+=7;
    oled_clear(b);
  } 
}
