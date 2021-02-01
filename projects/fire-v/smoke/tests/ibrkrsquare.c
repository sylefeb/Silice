
#include "../mylibc/mylibc.h"

void main()
{
  int fbuffer = 0;
  int time = 0;

   while (1) {    
   
    int xmin=120,xmax=200;
    int ymin=30,ymax=70;
   
    clear(0,0,320,100);
   
    int yoffs = - (fbuffer<<5) + (costbl[(time)&255]);
    draw_triangle(31,0, 
      xmin<<5,(ymin<<5) + yoffs, 
      xmax<<5,(ymin<<5) + yoffs, 
      xmax<<5,(ymax<<5) + yoffs);
    draw_triangle(72,0, 
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
