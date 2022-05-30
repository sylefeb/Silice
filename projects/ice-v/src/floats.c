#include "config.h"
#include <math.h>

void main()
{  
  float f = 1.111111f;
  for (int i = 0 ; i < 20 ; ++i) {
    f = f * f;
    *LEDS = (int)round(f);
  }
}
