#include "../mylibc/mylibc.h"

void pause(int cycles)
{ 
  long tm_start = time();
  while (time() - tm_start < cycles) { }
}

void draw_triangle(char color,int px0,int py0,int px1,int py1,int px2,int py2)
{
  int tmp;

  //if (py1-py0 == 0 || py2-py1 == 0 || py2-py0 == 0) return;
  //if (px1-px0 == 0 || px2-px1 == 0 || px2-px0 == 0) return;

  // front facing?
  int d10x  = px1 - px0;
  int d10y  = py1 - py0;
  int d20x  = px2 - px0;
  int d20y  = py2 - py0;
  int cross = d10x*d20y - d10y*d20x;
  if (cross <= 0) return;

  // 0 smallest y , 2 largest y
  if (py0 > py1) {
    tmp = py1; py1 = py0; py0 = tmp;
    tmp = px1; px1 = px0; px0 = tmp;
  }
  if (py0 > py2) {
    tmp = py2; py2 = py0; py0 = tmp;
    tmp = px2; px2 = px0; px0 = tmp;
  }
  if (py1 > py2) {
    tmp = py2; py2 = py1; py1 = tmp;
    tmp = px2; px2 = px1; px1 = tmp;
  }

  // setup edge increments for hardware rasterizer
  int e_incr0 = (py1-py0 == 0) ? 0xFFFFF : ((px1-px0)<<10) / (py1-py0);
  int e_incr1 = (py2-py1 == 0) ? 0xFFFFF : ((px2-px1)<<10) / (py2-py1);
  int e_incr2 = (py2-py0 == 0) ? 0xFFFFF : ((px2-px0)<<10) / (py2-py0);

  if ((e_incr0 == 0xFFFFF && e_incr1 == 0xFFFFF) 
   || (e_incr0 == 0xFFFFF && e_incr2 == 0xFFFFF) 
   || (e_incr1 == 0xFFFFF && e_incr2 == 0xFFFFF)) {
    // flat triangle
    return; 
  }

  // wait for any pending draw to complete
  while (((*LEDS)&1) == 1) { (*LEDS)++; }

  // send commands
  *(TRIANGLE+  1) = px0 | (py0 << 16);
  *(TRIANGLE+  2) = px1 | (py1 << 16);
  *(TRIANGLE+  4) = px2 | (py2 << 16);
  *(TRIANGLE+  8) = (e_incr0&0xffffff) | (color << 24);
  *(TRIANGLE+ 16) = (e_incr1&0xffffff);
  *(TRIANGLE+ 32) = (e_incr2&0xffffff);
  *(TRIANGLE+ 64) = ((py2+1/*simplifies termination test in hardware*/) << 16) | py0;
}

void main()
{
  // draw_triangle(31, 20,10, 80,10, 40,40);

  draw_triangle(31, 10,10, 40,50, 10,100);

  while (((*LEDS)&1) == 1) { (*LEDS)++; }
  *(LEDS+4) = 1; // swap buffers
}
