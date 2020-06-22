#include "oled.h"

void starfield(int time)
{
  int rng = 31421;
  for (int v=0;v<128;v++) {
    rng = ((rng<<5) ^ 6927) + (rng ^ v);
    rng = ((rng) ^ 31421) + (v);
    for (int u=0;u<128;u++) {
      if (u == (((time<<(v&3)) + rng)&127)) {
        int clr = (1+(v&3))<<4;
        if (clr > 63) clr = 63;
        oled_pix(clr,clr,clr);
      } else {
        oled_pix(0,0,0);
      }
    }  
  }
}

void main() 
{
  *(LEDS) = 5;

  oled_init();
  oled_fullscreen();
  int time = 0;
  while (1) {
    starfield(time);
    -- time;
  }   
}
