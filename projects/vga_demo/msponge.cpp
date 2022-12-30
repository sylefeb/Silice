// SL 2022-10-31 
//
// g++ msponge.cpp -lopengl32 -lfreeglut
//
// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice

/*

This is a reference implementation of the dda algorithm and Menger sponge
in vga_msponge.si

I used this when prototyping the rendering algorithm, and it particular it
mimics the fixed point computations so I can check for precision issues.
This is obviously not meant for performance comparisons!

I also made a GPU version available on shadertoy:
https://www.shadertoy.com/view/DdB3zR

*/
#include <GL/gl.h>
#include <GL/glut.h>
#include <cmath>
#include <ctime>
#include <iostream>

// ----------------------------------------------------------------------------

GLuint         g_FBtexture = 0; // OpenGL texture
unsigned char *g_Pixels = NULL;
int            g_Frame = 1800;

const int W = 1920;
const int H = 1080;

typedef int uint;

// ----------------------------------------------------------------------------


int icos(int v)
{
  return (int)(1024.0*cos(3.14159*2.0*(double)(v&511)/512.0));
}

int isin(int v)
{
  return (int)(1024.0*sin(3.14159*2.0*(double)(v&511)/512.0));
}

int inv(int v)
{
  return v == 0 ? ((1<<17)-1) : ((1<<18) / abs(v));
}

void draw_frame()
{
 const int tile[64] = {
   1,1,1,1,
   1,0,0,1,
   1,0,0,1,
   1,1,1,1,

   1,0,0,1,
   0,0,0,0,
   0,0,0,0,
   1,0,0,1,

   1,0,0,1,
   0,0,0,0,
   0,0,0,0,
   1,0,0,1,

   1,1,1,1,
   1,0,0,1,
   1,0,0,1,
   1,1,1,1
 };

  for (int j=0 ; j<H ; ++j) {
    for (int i=0 ; i<W ; ++i) {

#define N_steps 256

      uint y=0u;         uint x=(0u);      uint wait=(0u);
      int  view_x=(0);    int view_y=(0);  int  view_z=(0);
      int  rot_x=(0);     int rot_y=(0);
      uint  inside=(0u);
      uint  clr=(0u);       uint  dist=(0u);
      uint  clr_r=(0u);     uint  clr_g=(0u);   uint  clr_b=(0u);
      int  cs0=(0);       int  ss0=(0);
      int  cs1=(0);       int  ss1=(0);
      int  r_x_delta=(0); int  r_z_delta=(0);

    view_x    = (int(i) - int(W/2));
    view_y    = (int(j) - int(H/2));
    view_z    = 384;

    inside    = 0;
    dist      = 255;
    clr       = 0;

    int frame = g_Frame;

    cs0     = icos(frame>>1);
    ss0     = isin(frame>>1);
    cs1     = icos((frame+(frame<<1))>>3);
    ss1     = isin((frame+(frame<<3))>>4);

    rot_x   = (view_x * cs1);
    rot_y   = (view_x * ss1);

    view_x  = rot_x - (view_y * ss1);
    view_y  = rot_y + (view_y * cs1);

    view_x = view_x >> 10;
    view_y = view_y >> 10;

    // a 'voxel' is 1<<12
    int vxsz = 1<<12;
    // 1<<11 is half a small 'voxel' (a cube in the smallest 4x4x4 struct)
    // level 0 is 1<<14 (4x4x4)
    // level 1 is 1<<16 (4x4x4)
    // level 2 is 1<<18 (4x4x4)
    // compute the ray direction (through rotations)
    int xcs = view_x * cs0;
    int xss = view_x * ss0;
    int zcs = view_z * cs0;
    int zss = view_z * ss0;
    r_x_delta = (xcs - zss);
    r_z_delta = (xss + zcs);
    // ray dir is (r_x_delta, view_y, r_z_delta)
    int rd_x  = r_x_delta>>10;
    int rd_y  = view_y;
    int rd_z  = r_z_delta>>10;
    // initialize voxel traversal
    // -> position
    int p_x   = (68<<11);
    int p_y   = (12<<11);
    int p_z   = (frame<<9);
    // -> start voxel
    int v_x   = p_x >> 12;
    int v_y   = p_y >> 12;
    int v_z   = p_z >> 12;
    // -> steps
    int s_x   = rd_x < 0 ? -1 : 1;
    int s_y   = rd_y < 0 ? -1 : 1;
    int s_z   = rd_z < 0 ? -1 : 1;
    // -> inv dot products
    int inv_x = inv(rd_x);
    int inv_y = inv(rd_y);
    int inv_z = inv(rd_z);
    // -> tmax
    int brd_x = (p_x - (v_x<<12)); // distance to border
    int brd_y = (p_y - (v_y<<12)); // distance to border
    int brd_z = (p_z - (v_z<<12)); // distance to border
    int tm_x  = ((rd_x < 0 ? (brd_x) : (vxsz - brd_x)) * inv_x)>>12;
    int tm_y  = ((rd_y < 0 ? (brd_y) : (vxsz - brd_y)) * inv_y)>>12;
    int tm_z  = ((rd_z < 0 ? (brd_z) : (vxsz - brd_z)) * inv_z)>>12;
    // -> delta
    int dt_x  = ((vxsz * inv_x)>>12)-1;
    int dt_y  = ((vxsz * inv_y)>>12)-1;
    int dt_z  = ((vxsz * inv_z)>>12)-1;

    int step;
    for (step=0 ; step<N_steps ; ++step)
    {
      int w_x = v_x; int w_y = v_y; int w_z = v_z;

      int  tex     = ((v_x)&63) ^ ((v_y)&63) ^ ((v_z)&63);
      int  vnum0   = (((w_z>>0)&3)<<4) | (((w_y>>0)&3)<<2) | (((w_x>>0)&3)<<0);
      int  vnum1   = (((w_z>>2)&3)<<4) | (((w_y>>2)&3)<<2) | (((w_x>>2)&3)<<0);
      int  vnum2   = (((w_z>>4)&3)<<4) | (((w_y>>4)&3)<<2) | (((w_x>>4)&3)<<0);
      if ((tile[vnum0] & tile[vnum1] & tile[vnum2]) != 0) {
        if (inside == 0u) {
          clr    = uint(tex);
          dist   = uint(step);
          inside = 1u;
          break;
        }
      }

      if (tm_x <= tm_y && tm_x <= tm_z) {
        // tm_x smallest
        v_x  = v_x  + s_x;
        tm_x = tm_x + dt_x;
      } else if (tm_y < tm_x && tm_y < tm_z) {
        // tm_y smallest
        v_y  = v_y  + s_y;
        tm_y = tm_y + dt_y;
      } else {
        // tm_z smallest
        v_z  = v_z  + s_z;
        tm_z = tm_z + dt_z;
      }

    }

    uint fog   = dist;
    uint light = (256u - dist);
    uint shade = light * clr;

    clr_r = (shade >> 7) + fog;
    clr_g = (shade >> 7) + fog;
    clr_b = (shade >> 8) + fog;

     g_Pixels[((i+j*W)<<2) + 0] = clr_r;
     g_Pixels[((i+j*W)<<2) + 1] = clr_g;
     g_Pixels[((i+j*W)<<2) + 2] = clr_b;
     g_Pixels[((i+j*W)<<2) + 3] = 255;
    }
  }
}

// ----------------------------------------------------------------------------

void render()
{
  // CPU draw
  std::clock_t tm_start = std::clock();
  draw_frame();
  std::clock_t tm_end = std::clock();
  auto tm_el = 1000.0 * (tm_end-tm_start) / CLOCKS_PER_SEC;
  std::cerr << "elapsed: " << tm_el << " msec. frame " << g_Frame << " \n";
  g_Frame += 16;
  // refresh texture
  glTexSubImage2D( GL_TEXTURE_2D,0,0,0,
                W,H,
                GL_RGBA,GL_UNSIGNED_BYTE,
                g_Pixels);
  glBegin(GL_QUADS);
  glTexCoord2f(0.0f, 0.0f); glVertex2f(0.0f, 0.0f);
  glTexCoord2f(1.0f, 0.0f); glVertex2f(1.0f, 0.0f);
  glTexCoord2f(1.0f, 1.0f); glVertex2f(1.0f, 1.0f);
  glTexCoord2f(0.0f, 1.0f); glVertex2f(0.0f, 1.0f);
  glEnd();
  // swap buffers
  glutSwapBuffers();
  // ask glut to immediately redraw
  glutPostRedisplay();
}

// ----------------------------------------------------------------------------

int main(int argc,char **argv)
{
  // glut window
  glutInit(&argc, argv);
  glutInitDisplayMode(GLUT_RGBA | GLUT_SINGLE);
  glutInitWindowSize(W,H);
  glutCreateWindow("");
  // pixels
  g_Pixels = new unsigned char[W*H*4];
  // prepare texture
  glGenTextures(1,&g_FBtexture);
  glBindTexture(GL_TEXTURE_2D,g_FBtexture);
  glTexImage2D( GL_TEXTURE_2D,0, GL_RGBA,
                W,H,0,
                GL_RGBA,GL_UNSIGNED_BYTE, NULL);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
  // setup rendering
  glDisable(GL_DEPTH_TEST);
  glDisable(GL_LIGHTING);
  glDisable(GL_CULL_FACE);
  glEnable(GL_TEXTURE_2D);
  glColor3f(1.0f,1.0f,1.0f);
  // setup view
  glViewport(0,0,W,H);
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  glOrtho(0.0f, 1.0f, 1.0f, 0.0f, -1.0f, 1.0f);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
  // enter main loop
  glutDisplayFunc(render);
  glutMainLoop();
}

// ----------------------------------------------------------------------------
