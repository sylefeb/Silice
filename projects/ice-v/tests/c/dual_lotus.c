
// == to test on desktop: use following command line to produce tmp.html,
//    open in firefox to see a preview of the rendering
// gcc tests/c/dual_lotus.c ; ./a.exe > tmp.html

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
  printf("<circle cx=\"%d\" cy=\"%d\" r=\"1.0\" stroke=\"none\" fill=\"rgb(%d,%d,%d)\" />\n",oled_x,127-oled_y,(r&63)*4,(g&63)*4,(b&63)*4);
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


unsigned int __mulsi3 (unsigned int ia, unsigned int ib)
{
  register unsigned int a = ia;
  register unsigned int b = ib;
  register unsigned int r = 0;

  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;

  if (!a) return r;

  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;

  if (!a) return r;

  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;

  if (!a) return r;

  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;

  if (!a) return r;

  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;

  if (!a) return r;

  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;

  return r;
}


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
      if (len > 508352 /*track length*/) {
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

	int turn    = 0;
	int tdir    = 1;
	int bump    = 0;
	int bdir    = 3;

  while (1) {
    
#ifdef EMUL
  printf("<svg height=\"128\" width=\"128\" viewBox=\"0 0 128 128\">\n");  
#endif

    int horizon = 32<<8;

    // for each line
    for (register int y=127;y>=0;--y) {

      offs_y = y - (horizon>>8) + 8;
			
      if (y < (horizon>>8)) {
        floor  = 0;
      } else {
        floor  = 1;
      }

      // result from division
      cur_inv_y = inv_y;

			horizon += (cur_inv_y*bump)>>8;
			
      register int clip  = ((cur_inv_y>>4) > 70 || floor == 0) ? 1 : 0;

      // start divide for next line
      numerator = maxv; 
      inv_y     = 0;    // when done, inv_y = maxv / offs_y
      offs_y_2  = offs_y<<1;
      offs_y_4  = offs_y<<2;
      offs_y_8  = offs_y<<3;

      int curve   = (floor?((cur_inv_y*turn)>>9):0);
			u           = (pos_u<<6) + (( 0 - 64 + curve ) * cur_inv_y) - (turn<<8);
      v           = pos_v + cur_inv_y;

			register int u_incr = cur_inv_y;

      for (register int x=0;x<128;x++) {
				
        register int r,g,b;
				if (y == 127) {
					r=g=b=0;
        } else if (clip) {
					int sky = (y-32);
          r = g = sky<0 ? 0 : sky;
					b = 255;
        } else {
					int dctr = u <   0 ? -u : u;
					dctr     = dctr >> 6;
					int road = dctr < 250 ? 1 : 0; // road width
					int band = ((dctr > 200 && dctr < 220) || dctr < 10) && (v&64) ? 1 : 0;
					if (band) {
						r = g = b = 63;
					} else if (road == 1) {
						if (v&64) { 
							r=4; g=7; b=5; 
						} else {
							r=7;  g=7; b=6; 
						}						
					} else {
						if (v&64) { 
							r=8;  g=20; b=0; 
						} else {
							r=7; g=15; b=0; 
						}
					}
        }
				
        oled_pix(r,g,b);

        // step division 
        // (indeed, we divide by subtracting multiples of the denominator)

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

        STEP_DIV;
        STEP_DIV;
        STEP_DIV;
				
				u += u_incr;
      }

    }	

    // prepare next frame
    pos_v = pos_v + 32; 

#ifdef EMUL
    printf("</svg><br>&nbsp;<br>&nbsp;<br>\n");
    if (frame > 3) {
      printf("</body></html>\n");
      exit (-1);
    }
    ++ frame;
    frame_flash += 16;
		turn        += 8;
#else
    frame_flash = flash>>3;
		turn += (frame_flash > 20) ? tdir : -tdir;
		if (turn > 64) {
			turn = 64;
			tdir = -1;
		} else if (turn < -64) {
			turn = -64;
			tdir = 1;
		}
		bump       += bdir;
		if (bump > 96 || bump < -96) {
			bdir = - bdir;
		}
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

