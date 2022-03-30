// MIT license, see LICENSE_MIT in Silice repo root
// @sylefeb 2021
// https://github.com/sylefeb/Silice

#include "config.h"

#include "tunnel.h" // see pre_tunnel.cc, run it first

// Bayer 8x8 matrix, each row repeated 4 times for efficiency
int bayer_8x8[64*4] = { // non const, ends up in RAM
  0, 32, 8, 40, 2, 34, 10, 42, 0, 32, 8, 40, 2, 34, 10, 42, 0, 32, 8, 40, 2, 34, 10, 42, 0, 32, 8, 40, 2, 34, 10, 42,
  48, 16, 56, 24, 50, 18, 58, 26, 48, 16, 56, 24, 50, 18, 58, 26, 48, 16, 56, 24, 50, 18, 58, 26, 48, 16, 56, 24, 50, 18, 58, 26,
  12, 44, 4, 36, 14, 46, 6, 38, 12, 44, 4, 36, 14, 46, 6, 38, 12, 44, 4, 36, 14, 46, 6, 38, 12, 44, 4, 36, 14, 46, 6, 38,
  60, 28, 52, 20, 62, 30, 54, 22, 60, 28, 52, 20, 62, 30, 54, 22, 60, 28, 52, 20, 62, 30, 54, 22, 60, 28, 52, 20, 62, 30, 54, 22,
  3, 35, 11, 43, 1, 33, 9, 41, 3, 35, 11, 43, 1, 33, 9, 41, 3, 35, 11, 43, 1, 33, 9, 41, 3, 35, 11, 43, 1, 33, 9, 41,
  51, 19, 59, 27, 49, 17, 57, 25, 51, 19, 59, 27, 49, 17, 57, 25, 51, 19, 59, 27, 49, 17, 57, 25, 51, 19, 59, 27, 49, 17, 57, 25,
  15, 47, 7, 39, 13, 45, 5, 37, 15, 47, 7, 39, 13, 45, 5, 37, 15, 47, 7, 39, 13, 45, 5, 37, 15, 47, 7, 39, 13, 45, 5, 37,
  63, 31, 55, 23, 61, 29, 53, 21, 63, 31, 55, 23, 61, 29, 53, 21, 63, 31, 55, 23, 61, 29, 53, 21, 63, 31, 55, 23, 61, 29, 53, 21,
};

static inline int core_id()
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles&1;
}

unsigned char texture[128*128]; // 16KB, we can afford it!

__attribute__((section(".data"))) void vram_fill(int core)
{
  unsigned int frame = 0;
  for (int j = 0; j < 128; ++j) {
    for (int i = 0; i < 128; ++i) {
      texture[i+(j<<7)] = (i^j)&63;
    }
  }
  while (1) {
    volatile int *VRAM             = core ? (volatile int *)0x80fa0
                                          : (volatile int *)0x80000;
    const unsigned int *tunnel_ptr = core ? (tunnel + 160*100)
                                          :  tunnel;
    for (int j=0 ; j < 100 ; ++j) {
      for (int i=0 ; i < 10 ; ++i) {
        unsigned int *bayer_ptr = bayer_8x8 + ((j&7)<<5);

        register unsigned int pixels = 0;
        register unsigned int pix    = 1;
        register unsigned int t,d,uv0,uv1,drk,ba0,ba1,cl0,cl1;

#define TUNNEL_TWO_PIX(shade) \
          /* table content for 2 pixels */ \
          t   = *tunnel_ptr++; \
          uv0 = t;           \
          uv1 = (t>>16);     \
          if (shade) { \
            d   = (uv0 & 127);   /* dist */\
            drk = d > 63 ? (d-63) : 0; /* darkening*/\
          } \
          ba0 = *(bayer_ptr++);\
          ba1 = *(bayer_ptr++);\
          cl0 = texture[(uv0 + frame)&16383];\
          cl1 = texture[(uv1 + frame)&16383];\
          pixels = pixels | (cl0 > ba0 + drk ? pix : 0);\
          pix  <<= 1;\
          pixels = pixels | (cl1 > ba1 + drk ? pix : 0);\
          pix  <<= 1;

        TUNNEL_TWO_PIX(1); TUNNEL_TWO_PIX(0); TUNNEL_TWO_PIX(0); TUNNEL_TWO_PIX(0);
        TUNNEL_TWO_PIX(1); TUNNEL_TWO_PIX(0); TUNNEL_TWO_PIX(0); TUNNEL_TWO_PIX(0);
        TUNNEL_TWO_PIX(1); TUNNEL_TWO_PIX(0); TUNNEL_TWO_PIX(0); TUNNEL_TWO_PIX(0);
        TUNNEL_TWO_PIX(1); TUNNEL_TWO_PIX(0); TUNNEL_TWO_PIX(0); TUNNEL_TWO_PIX(0);

        *(VRAM++) = pixels;
      }
    }
    frame += 2;
  }
}

void main()
{
  if (core_id()) {
    vram_fill(1);
  } else {
    vram_fill(0);
  }
  while (1) {} // hang
}
