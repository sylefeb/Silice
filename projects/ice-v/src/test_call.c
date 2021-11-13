// MIT license, see LICENSE_MIT in Silice repo root
// @sylefeb 2021
// https://github.com/sylefeb/Silice

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
