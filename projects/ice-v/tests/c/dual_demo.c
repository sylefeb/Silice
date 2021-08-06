
// == to test on desktop: 1) uncomment next line and 2) compile+launch with gcc
// #define EMUL
// gcc tests/c/dual_demo.c ; ./a.exe > tmp.html

// == music sample from
// Demo group Sanity
// http://modp3.mikendezign.com/index.php?modid=17

volatile int* const SOUND = (int*)0x2020;

#ifndef EMUL

#include "oled.h"
#include "spiflash.c"

static inline unsigned int rdcycle() 
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles;
}

#else

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

unsigned int rdcycle() { return 1; }
int oled_x = 0;
int oled_y = 0;
void oled_init() 
{
  printf("<html><body style=\"background-color: #000000;\">\n");
}
void oled_fullscreen() 
{

}
void oled_pix(unsigned char r,unsigned char g,unsigned char b) 
{
  printf("<circle cx=\"%d\" cy=\"%d\" r=\"1.0\" stroke=\"none\" fill=\"rgb(%d,%d,%d)\" />\n",oled_x,oled_y,(r&63)*4,(g&63)*4,(b&63)*4);
  ++ oled_x;
  if (oled_x == 128) {
    oled_x = 0;
    ++ oled_y;
    if (oled_y == 128) {
      oled_y = 0;
    }
  }
}
void oled_comp(unsigned char c)
{
  static int cnt = 0;
  static unsigned char r,g;
  if (cnt == 0) {
    r = c;
    ++cnt;
  } else if (cnt == 1) {
    g = c;
    ++cnt;
  } else if (cnt == 2) {
    oled_pix(r,g,c);
    cnt = 0;
  }
}
void spiflash_init() {}
void spiflash_read_begin(int addr){}
unsigned char spiflash_read_next(){}
void spiflash_read_end(){}
#endif

#define TIME  (rdcycle()>>1)
#define CPUID (rdcycle()&1)

void main_sound()
{
  unsigned int cy_last = TIME;
  unsigned int cy;

  int len = 0;

  spiflash_init();
  spiflash_read_begin(1<<20/*1MB SPIflash offset for music track*/);
  while (1) {
    cy = TIME;
    if (cy < cy_last) { cy_last = cy; } // counter may wrap around
    if (cy > cy_last + 1407 /*1641 70MHz*/) {
      *SOUND  = spiflash_read_next();
      cy_last = cy;
      len ++;
      if (len > 1266893 /*track length*/) {
        spiflash_read_end();
        spiflash_read_begin(1<<20/*SPIflash offset*/);
        len = 0;
      }
    }
  }
}

void main_oled()
{
  oled_init();
  oled_fullscreen();

  register int inv_y     = 0;
  register int numerator = 0;
  register int cur_inv_y = 0;
  register int offs_y    = 0;
  register int offs_y_2  = 0;
  register int offs_y_4  = 0;
  register int offs_y_8  = 0;
  register int u         = 0;
  register int v         = 0;
  register int maxv      = (1<<14);
  register int pos_u     = 0;
  register int pos_v     = 0;
  register int lum       = 0;
  register int floor     = 0;

  int frame = 0;

  while (1) {
    
#ifdef EMUL
  printf("<svg height=\"128\" width=\"128\" viewBox=\"0 0 128 128\">\n");
#endif

    // for each line
    for (register int y=0;y<128;y++) {

      if (y < 64) {
        offs_y = 64 - y + 8;
        floor  = 0;
      } else {
        offs_y = y - 64 + 8;
        floor  = 1;
      }

      // result from division
      cur_inv_y = inv_y;
      lum = (cur_inv_y>>4);
      if (lum < 70) {
        lum = 70 - lum;
        if (lum > 63) {
          lum = 63;
        }
      } else {
        lum = 0;
      }

      // start divide for next line
      numerator = maxv; // when done, inv_y = maxv / offs_y
      inv_y     = 0;
      offs_y_2  = offs_y<<1;
      offs_y_4  = offs_y<<2;
      offs_y_8  = offs_y<<3;

      for (register int x=0;x<128;x++) {

        u = pos_u + ((x - 64) * cur_inv_y) >> 6;
        v = pos_v + cur_inv_y;

        // step division 
        // (yes! we divide by subracting the denominator,
        //  but we have plenty of time to do that)

#define STEP_DIV \
        if (numerator > offs_y_8) {       \
          numerator -= offs_y_8;          \
          inv_y += 8;                     \
        } else if (numerator > offs_y_4) {\
          numerator -= offs_y_4;          \
          inv_y += 4;                     \
        } else if (numerator > offs_y_2) {\
          numerator -= offs_y_2;          \
          inv_y += 2;                     \
        } else if (numerator > offs_y) {  \
          numerator -= offs_y;            \
          inv_y += 1;                     \
        }

        register int r,g,b;
        if ((u&64) ^ (v&64)) {
          if ((u&32) ^ (v&32)) {
            r=g=b=lum;
          } else {
            r=g=b=lum>>1;
          }
        } else {
          r=g=b=0;
          if ((u&32) ^ (v&32)) {
            if (floor) {
              g = lum;
            } else {
              b = lum;
            }
          } else {
            if (floor) {
              g = lum>>1;
            } else {
              b = lum>>1;
            }
          }
        }

        oled_pix(r,g,b);
        STEP_DIV;
        STEP_DIV;
        STEP_DIV;
      }

    }	

    // prepare next frame
    pos_u = pos_u + 1024;
    pos_v = pos_v + 3; 

#ifdef EMUL
    printf("</svg><br>&nbsp;<br>&nbsp;<br>\n");
    if (frame > 3) {
      printf("</body></html>\n");
      exit (-1);
    }
#endif    
    ++ frame;

  }
}

void main()
{
  if (CPUID == 1) {

    main_oled();

	} else {

    main_sound();

  }

}
