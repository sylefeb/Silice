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

__attribute__((section(".data"))) void vram_fill()
{
  unsigned int frame = 0;
  while (1) {
    volatile int *VRAM = (volatile int *)0x80000;
    const unsigned int *tunnel_ptr = tunnel;
    for (int j=0 ; j < 200 ; ++j) {
      for (int i=0 ; i < 10 ; ++i) {
        unsigned int pixels = 0;
        unsigned int *bayer_ptr = bayer_8x8 + ((j&7)<<5);
        for (unsigned int p=0,pix=1 ; p < 32 ; ++p, pix<<=1) {
          unsigned int t   = *tunnel_ptr++;
          unsigned int u   = (t &  65535);  // angle
          unsigned int v   = (t >> 16);     // dist
          unsigned int clr = ((u + frame) ^ (v - frame)) & 63;
          int          bay = *(bayer_ptr++);
          int          drk = v < 80 ? 80 - v : 0; // TODO pre-comp in table
          bay              = bay + drk;
          pixels = pixels | (clr > bay ? pix : 0);
        }
        *(VRAM++) = pixels;
      }
    }
    ++ frame;
  }
}

void main()
{
  if (core_id()) {

  } else {
    vram_fill();
  }
  while (1) {} // hang
}
