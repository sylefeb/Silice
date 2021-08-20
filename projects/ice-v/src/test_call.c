#include "config.h"

void leds(unsigned char l)
{
  *(LEDS) = l;
}

void main() 
{

  leds(3);
  leds(10);
  leds(3);
  leds(10);

}
