// MIT license, see LICENSE_MIT in Silice repo root

#include "../mylibc/mylibc.h"

void main()
{
  int time = 0;

   while (1) {    
   
    int xmin=120,xmax=200; // 320/2 +/- 40
    int ymin= 60,ymax=140; // 200/2 +/- 40
   
    clear(15, 0,0,320,200);
   
    int yoffs = (costbl[(time)&255])<<2;

    draw_triangle(7,0, 
      xmin<<5,(ymin<<5) + yoffs, 
      xmax<<5,(ymin<<5) + yoffs, 
      xmax<<5,(ymax<<5) + yoffs);
    draw_triangle(0,0, 
      xmin<<5,(ymin<<5) + yoffs,
      xmax<<5,(ymax<<5) + yoffs, 
      xmin<<5,(ymax<<5) + yoffs);

    // wait for any pending draw to complete
    while ((userdata()&1) == 1) {  }
    // wait for vblank
    while ((userdata()&2) == 0) {  }
    // swap buffers
    *(LEDS+4) = 1;

    fbuffer = 1 - fbuffer;
    ++ time;
    
  }
  
}
