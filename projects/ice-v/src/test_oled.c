// MIT license, see LICENSE_MIT in Silice repo root

#include "oled.h"

void main() 
{
  oled_init();
  oled_fullscreen();
  int b = 0;
  while (1) {
    b+=7;
    oled_clear(b);
  } 
}
