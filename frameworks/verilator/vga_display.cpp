/*

Copyright 2019, (C) Sylvain Lefebvre and contributors
List contributors with: git shortlog -n -s -- <filename>

MIT license

Permission is hereby granted, free of charge, to any person obtaining a copy of 
this software and associated documentation files (the "Software"), to deal in 
the Software without restriction, including without limitation the rights to 
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so, 
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all 
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER 
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN 
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

(header_2_M)

*/
// SL 2021-06-12

#include "VgaChip.h"

#include <mutex>
#include <thread>

#include <GL/gl.h>
#include <GL/glut.h>

// ----------------------------------------------------------------------------

// external definitions
extern VgaChip *g_VgaChip;
void step();

// ----------------------------------------------------------------------------

GLuint     g_FBtexture = 0; // OpenGL texture
std::mutex g_Mutex;         // Mutex to lock VgaChip during rendering

// ----------------------------------------------------------------------------

void simul()
{
  // thread running the simulation forever
  while (1) {
    // lock for safe concurrent use between drawer and simulation
    std::lock_guard<std::mutex> lock(g_Mutex); 
    // step
    step(); 
  }
}

// ----------------------------------------------------------------------------

void render()
{  
  // lock the mutex before accessing g_VgaChip
  std::lock_guard<std::mutex> lock(g_Mutex);
  // has the framebuffer changed?
  if (g_VgaChip->framebufferChanged()) {
    // yes: refresh frame
    glTexSubImage2D( GL_TEXTURE_2D,0,0,0, 640,480, GL_RGBA,GL_UNSIGNED_BYTE, 
                  g_VgaChip->framebuffer().pixels().raw());
    glBegin(GL_QUADS);
    glTexCoord2f(0.0f, 0.0f); glVertex2f(0.0f, 0.0f);
    glTexCoord2f(1.0f, 0.0f); glVertex2f(1.0f, 0.0f);
    glTexCoord2f(1.0f, 1.0f); glVertex2f(1.0f, 1.0f);
    glTexCoord2f(0.0f, 1.0f); glVertex2f(0.0f, 1.0f);
    glEnd();
    // swap buffers
    glutSwapBuffers();
  }
  // ask glut to immediately redraw
  glutPostRedisplay();
}

// ----------------------------------------------------------------------------

void vga_display_loop()
{
  // glut window
  int   argc=0;
  char *argv[1] = {NULL};
  glutInit(&argc, argv);
  glutInitDisplayMode(GLUT_RGBA | GLUT_SINGLE);
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
  // start simulation in a thread
  std::thread th(simul);
  // enter main loop
  glutMainLoop();
}

// ----------------------------------------------------------------------------
