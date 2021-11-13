// @sylefeb 2020
// https://github.com/sylefeb/Silice
// MIT license, see LICENSE_MIT in Silice repo root

#include "../mylibc/mylibc.h"

void main()
{
  /*while (1)*/ {

    draw_triangle(31,0, 10<<5,10<<5, 40<<5,50<<5, 10<<5,100<<5);

    while ((userdata()&1) == 1) {  }

   }

//  *(LEDS+4) = 1; // swap buffers
}
