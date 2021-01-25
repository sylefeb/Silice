#include "fonts/FCUBEF2.h"
#include "../mylibc/mylibc.h"

#define SCRW 640
#define SCRH 480
#define R    (SCRW/320)

const char *text = "                                               firev: riscv framework with hardware accelerated rasterization, 640x480 8bits palette, overclocked at 160mhz cpu and sdram, passes timing at 90 mhz cpu and 135 mhz sdram, written in silice.";
const char *curr = 0;
int scroll_x = 0;

void scroll()
{
  if (curr == 0) curr = text;
  // -- scroll_x;
  scroll_x -= 5;
  const char *str = curr;
  int cursor_x = 0;
  int screen_end = 0;
  while (*str) {
    int lpos = font_FCUBEF2_ascii[(*str)];
    if (lpos > -1) {
      int w            = font_FCUBEF2_width[(*str)];
      int screen_start = cursor_x + scroll_x;
      if (screen_start > SCRW-1) {
        return; // reached end of screen
      }
      screen_end = cursor_x + scroll_x + (w<<1);
      if (screen_end >= 0) {
        // draw letter
        screen_start = (screen_start<1)    ? 1      : screen_start;
        screen_end   = (screen_end>SCRW-2) ? SCRW-2 : screen_end;
        for (int j=0;j<(font_FCUBEF2_height<<1);j++) {
          for (int i=screen_start;i<screen_end;i++) {
            int li = i - (cursor_x + scroll_x);
            unsigned char f = font_FCUBEF2[lpos+(li>>1)+((j>>1)<<9)];
            if (f) {
              *( (FRAMEBUFFER + (fbuffer ? 0 : 0x1000000)) + (i + ((j+16)<<10)) ) = f;
            }
          }
        }
      }
      // next position
      cursor_x += (w<<1)+1;
    } else {
      cursor_x += 12;
    }
    ++str;
  }
  // passed end of text?
  if (screen_end < 0) {
    curr     = text; // restart scrolling on next frame
    scroll_x = 0;
  }
}

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

int trpts[8*3];

int idx[12*3] = {
  0*3,2*3,1*3, 0*3,3*3,2*3,
  4*3,5*3,6*3, 4*3,6*3,7*3,
  0*3,1*3,5*3, 0*3,5*3,4*3,
  1*3,2*3,5*3, 2*3,6*3,5*3,
  3*3,6*3,2*3, 3*3,7*3,6*3,
  0*3,4*3,3*3, 4*3,7*3,3*3
};

void transform(const int *M,int p)
{
  trpts[p+0] = (pts[p+0]*M[0] + pts[p+1]*M[1] + pts[p+2]*M[2]) >> 2; // keeping precision (<<5)
  trpts[p+1] = (pts[p+0]*M[3] + pts[p+1]*M[4] + pts[p+2]*M[5]) >> 2; // for better shading
  trpts[p+2] = (pts[p+0]*M[6] + pts[p+1]*M[7] + pts[p+2]*M[8]) >> 2;
}

void transform_points(const int *M)
{
  for (int p = 0; p < 24 ; p = p + 3) {
    transform(M,p);
  }
}

void main()
{

  char a   = 66;
  char b   = 31;
  char c   = 0;
  int time = 0;
  
  // pause(1000000);
  //fb_cleanup();

  clear(0,0,SCRW,SCRH);
  swap_buffers(0);
  clear(0,0,SCRW,SCRH);

  while(1) {
    
    clear(0,0,SCRW,SCRH);

    scroll();

    int pos = 0;
    for (int posy = -70*R; posy <= 70*R ; posy += 35*R) {
      for (int posx = -140*R; posx <= 140*R ; posx += 35*R) {
        int Ry[9];
        rotY(Ry,a + costbl[((posx>>2) + (posy>>2) + (time<<1))&255]);
        int Rz[9];
        rotZ(Rz,b + (costbl[((posx>>2) - (posy>>2) + (time<<1))&255]>>1));
        int Rx[9];
        rotX(Rx,c + (costbl[((posx>>3) + (posy>>4) + (time<<2))&255]>>1)>>2 );
        int Ra[9];
        mulM(Ra,Rz,Ry);
        int M[9];
        mulM(M,Ra,Rx);
        transform_points(M);
        for (int t = 0; t < 36 ; t+=3) {
          draw_triangle(
            t<6 ? 64 : (t<12 ? 128 : 0),
            1,
            trpts[idx[t+0]+0] + ((SCRW/2 + posx)<<5), trpts[idx[t+0]+1] + ((SCRH/2 + posy)<<5), 
            trpts[idx[t+1]+0] + ((SCRW/2 + posx)<<5), trpts[idx[t+1]+1] + ((SCRH/2 + posy)<<5), 
            trpts[idx[t+2]+0] + ((SCRW/2 + posx)<<5), trpts[idx[t+2]+1] + ((SCRH/2 + posy)<<5) 
            );
        }
      }    
    }

    swap_buffers(1);

    ++time;
  }

}
