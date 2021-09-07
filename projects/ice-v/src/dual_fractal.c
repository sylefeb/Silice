
// fixed point setup
#define FP     6
#define IP     (FP+3)
#define CUTOFF (4<<FP)

// to regenerate the squares table do (from projects/ice-v):
//    cd src ; gcc dual_fractal.c ; ./a.exe ; cd ..
// this outputs "squares.h"

#ifdef __riscv

#include "oled.h"

static inline int cpu_id() 
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles&1;
}

#include "squares.h"

// #define USE_MUL

#ifdef USE_MUL
//https://github.com/gcc-mirror/gcc/blob/master/libgcc/config/epiphany/mulsi3.c
// GPLv3
unsigned int __mulsi3 (unsigned int a, unsigned int b)
{
  unsigned int r = 0;
  while (a) {
      if (a & 1) r += b;
      a >>= 1; b <<= 1;
    }
  return r;
}
#endif

volatile int synch;

void main_loop(int who)  
{
  if (who == 0) {
    oled_init_mode(OLED_565);
    oled_fullscreen();
  }

#ifdef USE_MUL

  int offs = 0;
  while (who == 0) { // only core 0 will do something
    // V1 standard fixed point fractal with multiply
    for (int j = 0;j < 128; ++j) {
      int j_f = ((j-64)<<FP)>>5;   // y [ -2:2 ]
      for (int i = 0;i < 128; ++i) {
        int i_f = ((i-64)<<FP)>>5; // x [ -2:2 ]
        int x_f = i_f;
        int y_f = j_f;
        int it = 0;
        for (;it<32;++it) {
          int u_f  = (x_f*x_f)  >>FP;
          int v_f  = (y_f*y_f)  >>FP;
          int w_f  = (2*x_f*y_f)>>FP;
          y_f = w_f + j_f;
          x_f = u_f - v_f + i_f;
          if (u_f + v_f > CUTOFF) {
            break;
          }
        }
        it = (it + offs) & 31;
        oled_pix_565(0,it&31);
      }
    }
    ++offs;
  }

#else

#define MASK   ((1<<(IP+1))-1)
//#define CLAMP  ((1<<(IP-1))-1)

  int offs = 0;
  while (1) {

    int x_c = -256;
  	int y_c =  16;

    int j_f = -128; // - 64*2;
    int pix = who;
    for (int j = 0 ; j < 128 ; ++j) {
      int i_f = -128; // - 128*3 + offs;
      for (int i = who ; i < 128 ; i += 2/*two cores*/) {
        int x_f  = i_f;
        int y_f  = j_f;
        int n    = 0;
        int it_r = 0;
        int it_b = 0;
        for ( ; n<16 ; n++,it_r+=2,it_b+=8) {
//#define REMAP(X,A) A = X<0?-X:X; A = A<=CLAMP?A:CLAMP;
          int a_f = x_f & MASK;
          int b_f = y_f & MASK;
//          int a_f;
//          REMAP(x_f,a_f);
//          int b_f;
//          REMAP(y_f,b_f);
          int u_f = sq[a_f];
          int v_f = sq[b_f];
          int c_f = (x_f+y_f) & MASK;
//          int tmp = (x_f+y_f);
//          int c_f;
//          REMAP(tmp,c_f);
          int s_f = sq[c_f];
          int w_f = s_f - u_f - v_f;
          y_f     = w_f + j_f;
          x_f     = u_f - v_f + i_f;
          if (u_f + v_f > CUTOFF) {
            break;
          }
        }
        // wait on lock
        while (pix > synch) { }
        // send pixel
        oled_pix_565(it_b,it_r);
        // advance two pixels (meanwhile OLED completes)
        pix += 2;
        i_f += 2;
        // advance lock
        ++synch;
      }
      j_f += 1;
    } 
    ++offs;
  }
#endif
  
}

void main() 
{

  synch = 0;

  if (cpu_id() == 0) {

    main_loop(0);

  } else {

    main_loop(1);

  }

}

#else

#include <stdio.h>

// generates precomputation table
void main()
{
  unsigned short sq[1<<(IP+1)];

  int num_clamped = 0;
  for (int s = 0; s < (1<<(IP+1)) ; ++s) {
    int q = s;
    if (s >= (1<<IP)) {
      // negative part, we make it so after 'and-ing' the 
      // negative value with (1<<(IP+1))-1 we get the correct square
      q = (1<<(IP+1))-1-s;
    }
    sq[s]  = (q*q)>>FP;
    if (sq[s] >= (1<<IP)) {
      if (num_clamped == 0) {
        printf("first clamped at %d\n",s);
      }
      num_clamped ++;
      sq[s] = (1<<IP)-1;
    }
  }
  printf("num clamped: %d / %d",num_clamped,1<<(IP+1));

  FILE *f = fopen("squares.h","w");
  fprintf(f,"unsigned short sq[] = {");
  // for (int s = 0; s < (1<<(IP-1)) ; ++s) {
  for (int s = 0; s < (1<<(IP+1)) ; ++s) {
    if (s>0) fprintf(f,",");
    fprintf(f,"%d",sq[s]);
  }
  fprintf(f,"};\n");
  fclose(f);
}

#endif
