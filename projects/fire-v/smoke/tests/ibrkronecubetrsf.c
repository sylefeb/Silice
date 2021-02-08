#include "../mylibc/mylibc.h"

#define SCRW 320
#define SCRH 200
#define R    3

int pts[8*3] = {
  -R*10,-R*10,-R*10,
   R*10,-R*10,-R*10,
   R*10, R*10,-R*10,
  -R*10, R*10,-R*10,
  -R*10,-R*10, R*10,
   R*10,-R*10, R*10,
   R*10, R*10, R*10,
  -R*10, R*10, R*10,
};

int idx[12*3] = {
  0,2,1, 0,3,2,
  4,5,6, 4,6,7,
  0,1,5, 0,5,4,
  1,2,5, 2,6,5,
  3,6,2, 3,7,6,
  0,4,3, 4,7,3
};

void transform_points(const int *M)
{
  *(TRIANGLE+ 7) = (M[0]&1023) | ((M[1]&1023)<<8) | ((M[2]&1023)<<16);
  *(TRIANGLE+ 8) = (M[3]&1023) | ((M[4]&1023)<<8) | ((M[5]&1023)<<16);
  *(TRIANGLE+ 9) = (M[6]&1023) | ((M[7]&1023)<<8) | ((M[8]&1023)<<16);
  *(TRIANGLE+10) = (SCRW/2) | ((SCRH/2)<<16);
  *(TRIANGLE+11) = 1; // reinit write address
  for (int p = 0; p < 24 ; p = p + 3) {
    *(TRIANGLE+12) = (pts[p+0]&1023) | ((pts[p+1]&1023) << 10) | ((pts[p+2]&1023) << 20);
  }
}

void main()
{

  char a   = 66;
  char b   = 60;
  char c   = 64;
  int time = 0;
  
  // clear(0,0,SCRW,SCRH);
  
  while(1) {
    
    clear(0,0,SCRW,SCRH);

    int Ry[9];
    rotY(Ry,(a + time)&255);
    int Rz[9];
    rotZ(Rz,b + (costbl[time&255]>>1));
    int Rx[9];
    rotX(Rx,c + (costbl[time&255]>>1)>>2 );
    int Ra[9];
    mulM(Ra,Rz,Ry);
    int M[9];
    mulM(M,Ra,Rx);
    
    transform_points(M);

    unsigned int *trpts = (unsigned int *)0x10000;
    for (int t = 0; t < 36 ; t+=3) {
      draw_triangle(
        0, 0,
        (((trpts[idx[t+0]]&1023))<<5), (((trpts[idx[t+0]]>>10)&1023))<<5, 
        (((trpts[idx[t+1]]&1023))<<5), (((trpts[idx[t+1]]>>10)&1023))<<5, 
        (((trpts[idx[t+2]]&1023))<<5), (((trpts[idx[t+2]]>>10)&1023))<<5 
        );
    }

    ++time;
   
    // wait for any pending draw to complete
    while ((userdata()&1) == 1) {  }
    // wait for vblank
    while ((userdata()&2) == 0) {  }
    // swap buffers
    *(LEDS+4) = 1;
   
    fbuffer = 1 - fbuffer;
   
    // pause(200000);
    
  }

}
