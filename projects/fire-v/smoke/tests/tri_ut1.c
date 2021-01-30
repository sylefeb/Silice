
#include "../mylibc/mylibc.h"

void main()
{
  /*while (1)*/ {
    
    draw_triangle(31,0, 10,10, 40,50, 10,100);

    while ((userdata()&1) == 1) {  }

   }
  
//  *(LEDS+4) = 1; // swap buffers
}
