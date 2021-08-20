#include "config.h"

void main() 
{
  volatile int i = 0;

  *LEDS = 0x0f;
  
  int l = 1;

  while (1) {  
    l <<= 1;
    if (l > 8) {
      l = 1;
    }    
    *LEDS = l;       
    for (i=0;i<655360;i++) { }
  }

}
