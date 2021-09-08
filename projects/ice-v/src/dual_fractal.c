// ========== Real time Julia fractal on the ice-v-dual
// mul trick from http://cowlark.com/2018-05-26-bogomandel/index.html
//
// CPU0 computes even pixels, CPU1 odd pixels
// They are synchronized through synch

// ==== used to synchronize CPUs
volatile int synch;

// ==== fixed point setup
#define FP     6
#define IP     (FP+3)
#define CUTOFF (4<<FP)

#ifdef __riscv

#include "oled.h"
#include "dual_fractal_table.h"

// ==== returns the CPU ID
static inline int cpu_id() 
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles&1;
}

// ==== main render loop, runs on each core

void main_loop(int who)  
{
  if (who == 0) {
    oled_init_mode(OLED_565);
    oled_fullscreen();
  }

#define MASK   ((1<<(IP+1))-1)
#define CLAMP  ((1<<(IP-1))-1)
#define NEG    ((1<<(IP+1))  )

#define XCmin  -90
#define XCmax  (XCmin+40)
#define YCmin  10
#define YCmax  (YCmin+40)

	int x_c = XCmin; int x_c_i = 1;
  int y_c = YCmin; int y_c_i = 3;

  while (1) {

    int j_f = -64;
    int pix = who;
    for (int j = 0 ; j < 128 ; ++j) {
      int i_f = -64;
      for (int i = who ; i < 128 ; i += 2/*two cores*/) {
        int x_f  = i_f;
        int y_f  = j_f;
        int clr=0; int clr8=16;
        for ( ; clr<24 ; clr++,clr8+=8) {
          int a_f = x_f & MASK;
          int b_f = y_f & MASK;
          int u_f = sq[a_f];
          int v_f = sq[b_f];
          int c_f = (x_f+y_f) & MASK;
          int s_f = sq[c_f];
          int w_f = s_f - u_f - v_f;
          x_f     = u_f - v_f + x_c; // + i_f; // use for Mandlebrot
          y_f     = w_f       + y_c; // + j_f; // use for Mandlebrot
          if (u_f + v_f > CUTOFF) {
            break;
          }
        }
        // wait on lock
        while (pix > synch) { }
        // send pixel
        oled_pix_565(clr8,clr);
        // asm volatile ("nop;");
        // advance two pixels (meanwhile OLED completes)
        pix += 2;
        i_f += 2;
        // advance lock
        ++synch;
      }
      j_f += 1;
    }

    x_c += x_c_i;
    if (x_c < XCmin || x_c > XCmax) { x_c_i = - x_c_i; }
    y_c += y_c_i;
    if (y_c < YCmin || y_c > YCmax) { y_c_i = - y_c_i; }
    
  }
}

// ==== main calls the render loop for each CPU

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

// =================== this gets used when compiling with gcc one desktop =====
// =================== recomputes the dual_fractal_table.h file

// to regenerate the squares table do (from projects/ice-v):
//    cd src ; gcc dual_fractal.c ; ./a.exe ; cd ..
// this outputs "dual_fractal_table.h"

#include <stdio.h>

// generates precomputation table
void main()
{
  unsigned short sq[1<<(IP+1)];

  for (int s = 0; s < (1<<(IP+1)) ; ++s) {
    int q = s;
    if (s >= (1<<IP)) {
      // negative part, we make it so after 'and-ing' the 
      // negative value with (1<<(IP+1))-1 we get the correct square
      q = (1<<(IP+1))-1-s;
    }
    sq[s]  = (q*q)>>FP;
    if (sq[s] >= (1<<IP)) {
      sq[s] = (1<<IP)-1;
    }
  }

  FILE *f = fopen("dual_fractal_table.h","w");
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
