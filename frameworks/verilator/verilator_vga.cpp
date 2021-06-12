/*

    Silice FPGA language and compiler
    (c) Sylvain Lefebvre - @sylefeb

This work and all associated files are under the

     GNU AFFERO GENERAL PUBLIC LICENSE
        Version 3, 19 November 2007
        
A copy of the license full text is included in 
the distribution, please refer to it for details.

(header_1_0)
*/
// SL 2019-09-23

#include "Vtop.h"

#include "VgaChip.h"

#include <GL/gl.h>
#include <GL/glut.h>

#include <mutex>
#include <thread>

Vtop    *g_VgaTest = nullptr;
VgaChip *g_VgaChip = nullptr;

GLuint   g_FBtexture = 0;

unsigned int g_MainTime = 0;
double sc_time_stamp()
{
  return g_MainTime;
}

std::mutex g_Mutex;

void step()
{
  if (Verilated::gotFinish()) {
    exit (0);
  }

  g_VgaTest->clk = 1 - g_VgaTest->clk;

  g_VgaTest->eval();

  {
    std::lock_guard<std::mutex> lock(g_Mutex);
    g_VgaChip->eval(
        g_VgaTest->video_clock,
        g_VgaTest->video_vs,g_VgaTest->video_hs,
        g_VgaTest->video_r, g_VgaTest->video_g,g_VgaTest->video_b);
  }

  g_MainTime ++;
}

void simul()
{
  while (1) { step(); }
}


void render()
{  
  std::lock_guard<std::mutex> lock(g_Mutex);

  if (g_VgaChip->framebufferChanged()) {

    // refresh frame
    glTexSubImage2D( GL_TEXTURE_2D,0,0,0, 640,480, GL_RGBA,GL_UNSIGNED_BYTE, 
                  g_VgaChip->framebuffer().pixels().raw());
    glBegin(GL_QUADS);
    glTexCoord2f(0.0f, 0.0f); glVertex2f(0.0f, 0.0f);
    glTexCoord2f(1.0f, 0.0f); glVertex2f(1.0f, 0.0f);
    glTexCoord2f(1.0f, 1.0f); glVertex2f(1.0f, 1.0f);
    glTexCoord2f(0.0f, 1.0f); glVertex2f(0.0f, 1.0f);
    glEnd();
    
    glutSwapBuffers();
  }

  glutPostRedisplay();
}

int main(int argc,char **argv)
{
  // Verilated::commandArgs(argc,argv);

  // instantiate design
  g_VgaTest = new Vtop();
  g_VgaTest->clk = 0;
  
  // we need to step simulation until we get the parameters
  do {
    g_VgaTest->clk = 1 - g_VgaTest->clk;
    g_VgaTest->eval();
  } while ((int)g_VgaTest->video_color_depth == 0);

  // instantiate VGA chip
  g_VgaChip = new VgaChip((int)g_VgaTest->video_color_depth);

  // glut window
  glutInit(&argc, argv);
  glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE);
  glutInitWindowSize(640, 480);
  glutCreateWindow("Silice verilator framework");
  glutDisplayFunc(render);
  // prepare texture
  glGenTextures(1,&g_FBtexture);
  glBindTexture(GL_TEXTURE_2D,g_FBtexture);
  glTexImage2D( GL_TEXTURE_2D,0, GL_RGBA, 640,480,0, GL_RGBA,GL_UNSIGNED_BYTE, 
                NULL);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
  // setup rendering
  glDisable(GL_DEPTH_TEST);
  glDisable(GL_LIGHTING);
  glDisable(GL_CULL_FACE);
  glEnable(GL_TEXTURE_2D);
  glColor3f(1.0f,1.0f,1.0f);
  // setup view
  glViewport(0,0,640,480);
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  glOrtho(0.0f, 1.0f, 1.0f, 0.0f, -1.0f, 1.0f);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();

  std::thread th(simul);

  // enter main loop
  glutMainLoop();

  return 0;
}

