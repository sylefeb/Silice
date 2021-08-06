
// == to test on desktop: use following command line to produce tmp.html,
//    open in firefox to see a preview of the rendering
// gcc tests/c/dual_demo.c ; ./a.exe > tmp.html

// == Music track has to be upload to SPIflash at offset 1 MB
//   The track length (in bytes) can be set below, see marker [1] 
//   PCM 8 bit signed, raw no header
// iceprog -o 1M track.raw

#ifndef __riscv
#define EMUL
#endif

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

volatile int flash = 0;

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
    if (cy > cy_last + 2110 ) {
      //  60MHz => 1407
      //  70MHz => 1641
      //  80MHz => 1876
      //  90MHz => 2110
      // 100MHz => 2345
      char smpl = spiflash_read_next();
      *SOUND   = smpl;
      if (smpl < 0) {
         smpl = -smpl;
      }
      if (smpl > flash) {
        flash = smpl;
      } else if (flash > 8) {
        flash -= 8;
      }
      cy_last = cy;
      len ++;
      if (len > 473975 /*track length in bytes*/) { // [1]
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

  int frame_flash = 0;
#ifdef EMUL
  int frame = 0;
#endif

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
      register int clip  = (cur_inv_y>>4) > 70 ? 1 : 0;      
      register int front = 60 + (frame_flash>>2) - (cur_inv_y>>4);
      register int back  = ( (cur_inv_y>>4) - 70 + frame_flash );
      front = front < 0 ? 0 : front;
      back  = back < 0 ? 0 : back;
      register int lum   = (front>>1) + back;
      lum   = lum > 63 ? 63 : lum;

      // start divide for next line
      numerator = maxv; 
      inv_y     = 0;    // when done, inv_y = maxv / offs_y
      offs_y_2  = offs_y<<1;
      offs_y_4  = offs_y<<2;
      offs_y_8  = offs_y<<3;

      for (register int x=0;x<128;x++) {

        u = pos_u + ((x - 64) * cur_inv_y) >> 6;
        v = pos_v + cur_inv_y;

        // step division 
        // (yes! we divide by subracting the denominator)

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
        if (clip) {
          r=g=b= back > 63 ? 63 : back;
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
    ++ frame;
    frame_flash += 16;
#else
    frame_flash = flash>>3;
#endif    

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

