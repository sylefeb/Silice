// MIT license, see LICENSE_MIT in Silice repo root
// @sylefeb 2020
// https://github.com/sylefeb/Silice

#include "../mylibc/mylibc.h"

#include "bunny3d.h"
// #include "dino3d.h" // NOTE: triangles are flipped, revert comparison in sort()

#define SCRW 320
#define SCRH 200

int  sorted[NTRIS]; // key<<16 | id   (64K triangles max ... anyway)

void init_sort()
{
  for (int i = 0; i < NTRIS ; i++) {
    sorted[i] = i;
  }
}

#define min(a,b) ((a)<(b)?(a):(b))
#define max(a,b) ((a)>(b)?(a):(b))

void update_sort()
{
  unsigned int *trpts = (unsigned int *)0x10004;
  for (int i = 0; i < NTRIS ; i++) {
    int t  = sorted[i]&65535;
    int t3 = t + (t<<1); // t*3
    int z0 = (trpts[idx[t3+0]]>>20)&1023;
    int z1 = (trpts[idx[t3+1]]>>20)&1023;
    int z2 = (trpts[idx[t3+2]]>>20)&1023;
    int z  = (z0+z1+z2);
    sorted[i] = (z<<16 | t);
  }
}

void sort() // bubble sort, assumes order is almost always correct
{
  register int iter = 3;
  while (iter-- > 0) {
    for (register int i = 0; i < NTRIS-1 ; i++) {
      register int n  = i + 1;
      register int sn = sorted[n];
      register int si = sorted[i];
      if (sn < si) {
        sorted[n] = si;
        sorted[i] = sn;
      }
    }
  }
}

void transform_points(const int *M)
{
  *(TRIANGLE+11) = 0; // set write address (due to internals, first is written on next, so 1)
  *(TRIANGLE+ 7) = (M[0]&1023) | ((M[1]&1023)<<8) | ((M[2]&1023)<<16);
  *(TRIANGLE+ 8) = (M[3]&1023) | ((M[4]&1023)<<8) | ((M[5]&1023)<<16);
  *(TRIANGLE+ 9) = (M[6]&1023) | ((M[7]&1023)<<8) | ((M[8]&1023)<<16);
  *(TRIANGLE+10) = ((SCRW/2)<<6) | (((SCRH/2)<<6)<<16);
  for (int p = 0; p < NVERTS*3 ; p = p + 3) {
    *(TRIANGLE+12) = ((pts[p+0]<<6)&65535) | (((pts[p+1]<<6)&65535) << 16);
    *(TRIANGLE+13) = ((pts[p+2]<<6)&65535);
  }
}

inline long my_userdata()
{
  int id;
  asm volatile ("rdtime %0" : "=r"(id));
  return id;
}

void draw_triangle_raw(int t,unsigned int p0,unsigned int p1,unsigned int p2)
{
  register int px0 = p0 & 1023;
  register int px1 = p1 & 1023;
  register int px2 = p2 & 1023;
  register int py0 = (p0>>10) & 1023;
  register int py1 = (p1>>10) & 1023;
  register int py2 = (p2>>10) & 1023;

  // front facing?
  register int d10x  = px1 - px0;
  register int d10y  = py1 - py0;
  register int d20x  = px2 - px0;
  register int d20y  = py2 - py0;
  register int cross = d10x*d20y - d10y*d20x;
  if (cross <= 0) return;

  int color    = (cross*inv_area[t])>>13;
  if (color > 14) color = 14;

  // 0 smallest y , 2 largest y
  if (py0 > py1) {
    register int tmp;
    tmp = py1; py1 = py0; py0 = tmp;
    tmp = px1; px1 = px0; px0 = tmp;
  }
  if (py0 > py2) {
    register int tmp;
    tmp = py2; py2 = py0; py0 = tmp;
    tmp = px2; px2 = px0; px0 = tmp;
  }
  if (py1 > py2) {
    register int tmp;
    tmp = py2; py2 = py1; py1 = tmp;
    tmp = px2; px2 = px1; px1 = tmp;
  }

  *(TRIANGLE+11) = NVERTS; // reinit write address, skip all transformed vertices
  *(TRIANGLE+14) = ((px1-px0)&65535) | ((py1-py0)<<16);
  *(TRIANGLE+15) = ((px2-px1)&65535) | ((py2-py1)<<16);
  *(TRIANGLE+ 6) = ((px2-px0)&65535) | ((py2-py0)<<16);

  // wait for divisions to complete
  while ((my_userdata()&32) == 32) {  }

  // result address
  unsigned int *e_incr = ((unsigned int *)0x10004) + NVERTS;

  // wait for any pending draw to complete
  while ((my_userdata()&1) == 1) {  }

  // send commands
  *(TRIANGLE+  0) = (px0) | ((py0) << 10);
  *(TRIANGLE+  1) = (px1) | ((py1) << 10);
  *(TRIANGLE+  2) = (px2) | ((py2) << 10);
  *(TRIANGLE+  3) = (e_incr[0]&0xffffff) | (color << 24);
  *(TRIANGLE+  4) = (e_incr[1]&0xffffff);
  *(TRIANGLE+  5) = (e_incr[2]&0xffffff);
}

void main()
{

  char a     = 66;
  char b     = 60;
  char c     = 64;
  int  frame = 0;

  *LEDS = 0;

  int posy = 0;
  int posx = 0;

  init_sort();

  unsigned int *trpts = (unsigned int *)0x10004;

  while(1) {

    clear(15, 0,0,SCRW,SCRH);

    ///////////////////////// update matrices
    int Rx[9];
    rotX(Rx,64);
    int Ry[9];
    rotY(Ry,(a + frame)&255);
    int M[9];
    mulM(M,Ry,Rx);

    ///////////////////////// transform
    //int tm_trsf_start = time();
    transform_points(M);
    //int tm_trsf_end   = time();

    ///////////////////////// sort
    //int tm_sort_start = time();
    update_sort();
    //int tm_sort_mid = time();
    sort();
    //int tm_sort_end = time();

    ///////////////////////// draw
    //int tm_tris_start = time();
    for (int i = 0; i < NTRIS ; i++) {
      int t  = sorted[i]&65535;
      int t3 = t + (t<<1);
      draw_triangle_raw(t,trpts[idx[t3+0]],trpts[idx[t3+1]],trpts[idx[t3+2]]);
    }
    //int tm_tris_end = time();
    //printf("trsf %d sort1 %d sort2 %d tris %d",tm_trsf_end-tm_trsf_start,tm_sort_mid-tm_sort_start,tm_sort_end-tm_sort_mid,tm_tris_end-tm_tris_start);
    //set_cursor(4,0);

    // wait for any pending draw to complete
    while ((my_userdata()&1) == 1) {  }
    // wait for vblank
    // while ((my_userdata()&2) == 0) {  }
    // swap buffers
    *(LEDS+4) = 1;
    fbuffer = 1 - fbuffer;

    ///////////////////////// next
    ++frame;

    // pause(200000);

  }

}
