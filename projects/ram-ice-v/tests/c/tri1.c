#include "../mylibc/mylibc.h"
#include "fonts/FCUBEF2.h"

char fbuffer = 0;

void pause(int cycles)
{ 
  long tm_start = time();
  while (time() - tm_start < cycles) { }
}

void print(int cursor_x,int cursor_y,const char *str)
{
  while (*str) {
    if (*str == 32) {
      cursor_x += 12;
    } else {
      int start = font_FCUBEF2_ascii[(*str)];
      if (start > -1) {
        int w   = font_FCUBEF2_width[(*str)];
        int end = start + w;
        end     = end > 320 ? 320 : end;
        //if (end > start) {
          for (int j=0;j<font_FCUBEF2_height;j++) {
            for (int i=0;i<w;i++) {
              *( (FRAMEBUFFER + (fbuffer ? 0 : 0x1000000)) + (cursor_x + i + ((cursor_y+j)<<9)) ) = font_FCUBEF2[start+i+(j<<9)];
              pause(1);
            }
          } 
          cursor_x += w+1;
        //} else {
        //  return;
        //}
      }
    }
    ++str;
  }
}

int pts[8*3] = {
  -10,-10,-10,
   10,-10,-10,
   10, 10,-10,
  -10, 10,-10,
  -10,-10, 10,
   10,-10, 10,
   10, 10, 10,
  -10, 10, 10,
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

int costbl[256] = {127,127,127,127,126,126,126,125,125,124,123,122,122,121,120,118,117,116,115,113,112,111,109,107,106,104,102,100,98,96,94,92,90,88,85,83,81,78,76,73,71,68,65,63,60,57,54,51,49,46,43,40,37,34,31,28,25,22,19,16,12,9,6,3,0,-3,-6,-9,-12,-16,-19,-22,-25,-28,-31,-34,-37,-40,-43,-46,-49,-51,-54,-57,-60,-63,-65,-68,-71,-73,-76,-78,-81,-83,-85,-88,-90,-92,-94,-96,-98,-100,-102,-104,-106,-107,-109,-111,-112,-113,-115,-116,-117,-118,-120,-121,-122,-122,-123,-124,-125,-125,-126,-126,-126,-127,-127,-127,-127,-127,-127,-127,-126,-126,-126,-125,-125,-124,-123,-122,-122,-121,-120,-118,-117,-116,-115,-113,-112,-111,-109,-107,-106,-104,-102,-100,-98,-96,-94,-92,-90,-88,-85,-83,-81,-78,-76,-73,-71,-68,-65,-63,-60,-57,-54,-51,-49,-46,-43,-40,-37,-34,-31,-28,-25,-22,-19,-16,-12,-9,-6,-3,0,3,6,9,12,16,19,22,25,28,31,34,37,40,43,46,49,51,54,57,60,63,65,68,71,73,76,78,81,83,85,88,90,92,94,96,98,100,102,104,106,107,109,111,112,113,115,116,117,118,120,121,122,122,123,124,125,125,126,126,126,127,127,127};

int fxcos(int angle)
{
  return costbl[angle&255];
}

int fxsin(int angle)
{
  return - costbl[(angle + 64)&255];
}

// fixed point, 128 == 1.0
void rotY(int *M, int angle)
{
  M[0] =  fxcos(angle); M[1] =   0; M[2] = fxsin(angle);
  M[3] =             0; M[4] = 128; M[5] =            0;
  M[6] = -fxsin(angle); M[7] =   0; M[8] = fxcos(angle);
}

void rotX(int *M, int angle)
{
  M[0] = fxcos(angle); M[1] = -fxsin(angle); M[2] =   0; 
  M[3] = fxsin(angle); M[4] =  fxcos(angle); M[5] =   0; 
  M[6] =            0; M[7] =             0; M[8] = 128;
}

void scale(int *M,int scale)
{
  M[0] = scale; M[1] =     0; M[2] = 0;
  M[3] =     0; M[4] = scale; M[5] = 0;
  M[6] =     0; M[7] =     0; M[8] = scale;
}

void transform(const int *M,int p)
{
  trpts[p+0] = (pts[p+0]*M[0] + pts[p+1]*M[1] + pts[p+2]*M[2]); // keeping precision (<<7)
  trpts[p+1] = (pts[p+0]*M[3] + pts[p+1]*M[4] + pts[p+2]*M[5]); // for better shading
  trpts[p+2] = (pts[p+0]*M[6] + pts[p+1]*M[7] + pts[p+2]*M[8]);
}

void mulM(int *M,const int *A,const int *B)
{
  M[0] = (A[0]*B[0] + A[1]*B[3] + A[2]*B[6]) >> 7;
  M[1] = (A[0]*B[1] + A[1]*B[4] + A[2]*B[7]) >> 7;
  M[2] = (A[0]*B[2] + A[1]*B[5] + A[2]*B[8]) >> 7;

  M[3] = (A[3]*B[0] + A[4]*B[3] + A[5]*B[6]) >> 7;
  M[4] = (A[3]*B[1] + A[4]*B[4] + A[5]*B[7]) >> 7;
  M[5] = (A[3]*B[2] + A[4]*B[5] + A[5]*B[8]) >> 7;

  M[6] = (A[6]*B[0] + A[7]*B[3] + A[8]*B[6]) >> 7;
  M[7] = (A[6]*B[1] + A[7]*B[4] + A[8]*B[7]) >> 7;
  M[8] = (A[6]*B[2] + A[7]*B[5] + A[8]*B[8]) >> 7;
}

void transform_points(const int *M)
{
  for (int p = 0; p < 24 ; p = p + 3) {
    transform(M,p);
  }
}

void draw_triangle(char color,char shade,int px0,int py0,int px1,int py1,int px2,int py2)
{
  int tmp;

  //if (py1-py0 == 0 || py2-py1 == 0 || py2-py0 == 0) return;
  //if (px1-px0 == 0 || px2-px1 == 0 || px2-px0 == 0) return;

  // front facing?
  int d10x  = px1 - px0;
  int d10y  = py1 - py0;
  int d20x  = px2 - px0;
  int d20y  = py2 - py0;
  int cross = d10x*d20y - d10y*d20x;
  if (cross <= 0) return;
  if (shade) {
    color = 0 + (cross >> 17);
  }

  // reduce precision after shading
  px0 >>= 7; py0 >>= 7;
  px1 >>= 7; py1 >>= 7;
  px2 >>= 7; py2 >>= 7;

  // 0 smallest y , 2 largest y
  if (py0 > py1) {
    tmp = py1; py1 = py0; py0 = tmp;
    tmp = px1; px1 = px0; px0 = tmp;
  }
  if (py0 > py2) {
    tmp = py2; py2 = py0; py0 = tmp;
    tmp = px2; px2 = px0; px0 = tmp;
  }
  if (py1 > py2) {
    tmp = py2; py2 = py1; py1 = tmp;
    tmp = px2; px2 = px1; px1 = tmp;
  }

  int e_incr0 = (py1-py0 == 0) ? 0xFFFFF : ((px1-px0)<<10) / (py1-py0);
  int e_incr1 = (py2-py1 == 0) ? 0xFFFFF : ((px2-px1)<<10) / (py2-py1);
  int e_incr2 = (py2-py0 == 0) ? 0xFFFFF : ((px2-px0)<<10) / (py2-py0);

  if ((e_incr0 == 0xFFFFF && e_incr1 == 0xFFFFF) 
   || (e_incr0 == 0xFFFFF && e_incr2 == 0xFFFFF) 
   || (e_incr1 == 0xFFFFF && e_incr2 == 0xFFFFF)) {
    // flat triangle
    return; 
  }

  // wait for any pending draw to complete
  while (((*LEDS)&1) == 1) { (*LEDS)++; }

  // send commands
  *(TRIANGLE+  1) = px0 | (py0 << 16);
  *(TRIANGLE+  2) = px1 | (py1 << 16);
  *(TRIANGLE+  4) = px2 | (py2 << 16);
  *(TRIANGLE+  8) = (e_incr0&0xffffff) | (color << 24);
  *(TRIANGLE+ 16) = (e_incr1&0xffffff);
  *(TRIANGLE+ 32) = (e_incr2&0xffffff);
  *(TRIANGLE+ 64) = (py2 << 16) | py0;
}

// cleanup the framebuffers
void fb_cleanup()
{
  for (int i=0;i<(480<<9)/4;i++) {
    *(( (volatile unsigned int*)FRAMEBUFFER) + i ) = 0xffffffff;
    *(( (volatile unsigned int*)(FRAMEBUFFER + 0x1000000)) + i ) = 0xffffffff;
  }
}

void clear()
{
  draw_triangle(8,0,
      0,  0, 
    320<<7,  0, 
    320<<7, 200<<7
    );
  draw_triangle(8,0,
      0,  0, 
    320<<7, 200<<7,
      0, 200<<7
    );
}

void main()
{
  char a = 66;
  char b = 31;
  int time = 0;
  fb_cleanup();
  while(1) {
    clear();
    //a = a + 1;
    //b = b + 1;
    int pos = 0;
    for (int posy = -64; posy <= 64 ; posy += 32) {
      for (int posx = -64; posx <= 64 ; posx += 32) {
        int Ry[9];
        rotY(Ry,a + costbl[((posx>>2) + (posy>>2) + (time>>1))&255]);
        int Rx[9];
        rotX(Rx,b + (costbl[((posx>>2) - (posy>>2) + (time>>1))&255]>>1));
        int M[9];
        mulM(M,Rx,Ry);
        transform_points(M);
        for (int t = 0; t < 36 ; t+=3) {
          draw_triangle(0,1,
            trpts[idx[t+0]+0] + ((160 + posx)<<7), trpts[idx[t+0]+1] + ((100 + posy)<<7), 
            trpts[idx[t+1]+0] + ((160 + posx)<<7), trpts[idx[t+1]+1] + ((100 + posy)<<7), 
            trpts[idx[t+2]+0] + ((160 + posx)<<7), trpts[idx[t+2]+1] + ((100 + posy)<<7) 
            );
        }
      }    
    }

    // print(0, 0,"firev: 160mhz framework");
    // print(0,16,"overclocked!");

    while (((*LEDS)&2) == 0) { (*LEDS)++; } // wait for vsync
    *(LEDS+4) = 1; // swap buffers

    fbuffer = 1-fbuffer;
    ++time;
  }

}
