#include "../mylibc/mylibc.h"

#include "model3d.h"

#define SCRW 320
#define SCRH 200

int trpts[NVERTS*3];

void transform(const int *M,int p)
{
  // keeping precision (<<5) for better shading
  trpts[p+0] = (pts[p+0]*M[0] + pts[p+1]*M[1] + pts[p+2]*M[2]) >> 2; 
  trpts[p+1] = (pts[p+0]*M[3] + pts[p+1]*M[4] + pts[p+2]*M[5]) >> 2;
  trpts[p+2] = (pts[p+0]*M[6] + pts[p+1]*M[7] + pts[p+2]*M[8]) >> 2;
}

void transform_points(const int *M)
{
  for (int p = 0; p < NVERTS*3 ; p = p + 3) {
    transform(M,p);
  }
}

void main()
{

  char a   = 66;
  char b   = 60;
  char c   = 64;
  int time = 0;
  
  // clear(0,0,SCRW,SCRH);
  
  *LEDS = 0;

  int posy = 0;
  int posx = 0;

  int Ry[9];
  rotY(Ry,(a + time)&255);
  int Rz[9];
  rotZ(Rz,b + (costbl[((posx>>2) - (posy>>2) + (time))&255]>>1));
  int Rx[9];
  rotX(Rx,c + (costbl[((posx>>3) + (posy>>4) + (time))&255]>>1)>>2 );
  int Ra[9];
  mulM(Ra,Rz,Ry);
  int M[9];
  mulM(M,Ra,Rx);

  transform_points(M);
 
  while(1) {
    
    clear(0,0,SCRW,SCRH);

    for (int t = 0; t < (NTRIS*3) ; t+=3) {
      draw_triangle(
        0,
        18,
        trpts[idx[t+0]+0] + ((SCRW/2 + posx)<<5), trpts[idx[t+0]+1] + ((SCRH/2 + posy)<<5), 
        trpts[idx[t+1]+0] + ((SCRW/2 + posx)<<5), trpts[idx[t+1]+1] + ((SCRH/2 + posy)<<5), 
        trpts[idx[t+2]+0] + ((SCRW/2 + posx)<<5), trpts[idx[t+2]+1] + ((SCRH/2 + posy)<<5) 
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
