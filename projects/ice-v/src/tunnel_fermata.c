// MIT license, see LICENSE_MIT in Silice repo root
// @sylefeb 2021
// https://github.com/sylefeb/Silice

#include "config.h"

#include "tunnel.h" // see pre_tunnel.cc, run it first

// Bayer 8x8 matrix, each row repeated 4 times for efficiency when drawing 32 pixel blocks
int bayer_8x8[8*8*4] = { // non const, ends up in RAM
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

__attribute__((section(".data"))) void draw_tunnel(int core)
{
  unsigned int shadow[10];
  unsigned int bayer_binary[8];
  unsigned int adv = 0;
  int opacity = 0; int opacity_dir = 1;
  int overlay = 1;
  while (1) {
    // fill pointers
    volatile int *VRAM              = core ? (volatile int *)0x80fa0
                                           : (volatile int *)0x80000;
    const unsigned int *tunnel_ptr  = core ? (tunnel + 160*100)
                                           : tunnel;
    const unsigned int *overlay_ptr;
    switch (overlay) {
      case  1: overlay_ptr = core ? (overlay2 + 10*100) : overlay2; break;
      case  2: overlay_ptr = core ? (overlay3 + 10*100) : overlay3; break;
      default: overlay_ptr = core ? (overlay1 + 10*100) : overlay1; break;
    }

    // reset shadow
    for (int i=0 ; i < 10 ; ++i) { shadow[i] = 0; }
    // bayer matrix for overlay transparency
    {
      const unsigned int *bayer_ptr = bayer_8x8;
      for (int j=0 ; j < 8 ; ++j) {
        unsigned int mask = 0;
        for (int i=0 ; i < 32 ; ++i) {
          mask |= opacity > *(bayer_ptr++) ? (1<<i) : 0;
        }
        bayer_binary[j] = mask;
      }
      // update opacity
      if (opacity > 64) {
        opacity     = 64;
        opacity_dir = -1;
      } else if (opacity <= 0) {
        opacity     = 0;
        opacity_dir = 1;
        overlay     = overlay + 1;
        if (overlay == 3) {
          overlay = 0;
        }
      }
      opacity += opacity_dir;
    }
    // draw frame
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
          cl0 = texture[(uv0 + adv)&16383];\
          cl1 = texture[(uv1 + adv)&16383];\
          pixels = pixels | (cl0 > ba0 + drk ? pix : 0);\
          pix  <<= 1;\
          pixels = pixels | (cl1 > ba1 + drk ? pix : 0);\
          pix  <<= 1;

        TUNNEL_TWO_PIX(1); TUNNEL_TWO_PIX(0); TUNNEL_TWO_PIX(0); TUNNEL_TWO_PIX(0);
        TUNNEL_TWO_PIX(1); TUNNEL_TWO_PIX(0); TUNNEL_TWO_PIX(0); TUNNEL_TWO_PIX(0);
        TUNNEL_TWO_PIX(1); TUNNEL_TWO_PIX(0); TUNNEL_TWO_PIX(0); TUNNEL_TWO_PIX(0);
        TUNNEL_TWO_PIX(1); TUNNEL_TWO_PIX(0); TUNNEL_TWO_PIX(0); TUNNEL_TWO_PIX(0);

        unsigned int overlay = *(overlay_ptr++);
        unsigned int mask    = bayer_binary[j&7];
        *(VRAM++)            = (pixels & ~(shadow[i]&mask)) | (overlay&mask);
        shadow[i]            = overlay;
      }
    }
    adv += 2 + (1<<7);
  }
}

void main()
{
  if (core_id()) {
    draw_tunnel(1);
  } else {
    draw_tunnel(0);
  }
  while (1) {} // hang
}
