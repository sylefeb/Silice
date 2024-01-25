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

#include "display.h"

#include <mutex>
#include <thread>

#ifdef __APPLE__
#include <OpenGL/gl.h>
#include <GLFW/glfw3.h>
#else
#include <GL/gl.h>
#include <GLFW/glfw3.h>
#endif

// ----------------------------------------------------------------------------

// external definitions
static DisplayChip *g_Chip = nullptr;

int step();

// ----------------------------------------------------------------------------

GLuint     g_FBtexture = 0; // OpenGL texture
std::mutex g_Mutex;         // Mutex to lock the chip during rendering

// ----------------------------------------------------------------------------

void refresh()
{
  glTexSubImage2D( GL_TEXTURE_2D,0,0,0,
                g_Chip->framebuffer().w(),g_Chip->framebuffer().h(),
                GL_RGBA,GL_UNSIGNED_BYTE,
                g_Chip->framebuffer().pixels().raw());
  glBegin(GL_QUADS);
  glTexCoord2f(0.0f, 0.0f); glVertex2f(0.0f, 0.0f);
  glTexCoord2f(1.0f, 0.0f); glVertex2f(1.0f, 0.0f);
  glTexCoord2f(1.0f, 1.0f); glVertex2f(1.0f, 1.0f);
  glTexCoord2f(0.0f, 1.0f); glVertex2f(0.0f, 1.0f);
  glEnd();
}

// ----------------------------------------------------------------------------

void simul()
{
#ifdef TRACE_FST
  // open trace
  VerilatedFstC *trace = new VerilatedFstC();
  Verilated::traceEverOn(true);
  bare_test->trace(trace, std::numeric_limits<int>::max());
  trace->open("trace.fst");
  int timestamp = 0;
#endif
  // thread running the simulation forever
  int keep_going = 1;
  while (keep_going) {
    // lock for safe concurrent use between drawer and simulation
    std::lock_guard<std::mutex> lock(g_Mutex);
    // step
    keep_going = step();
    #ifdef TRACE_FST
    // update trace
    trace->dump(timestamp++);
    #endif
  }
#ifdef TRACE_FST
  // close trace
  trace->close();
#endif

}

// ----------------------------------------------------------------------------

void render()
{
  // lock the mutex before accessing g_Chip
  std::lock_guard<std::mutex> lock(g_Mutex);
  // has the framebuffer changed?
  //if (g_Chip->framebufferChanged()) {
  // yes: refresh frame
  refresh();
  //}
}

// ----------------------------------------------------------------------------

void display_loop(DisplayChip *chip)
{
  g_Chip = chip;
  // glfw window
  if (!glfwInit()) {
    fprintf(stderr,"ERROR: cannot initialize glfw.");
    exit(-1);
  }
  GLFWwindow* window = NULL;
  if (g_Chip->framebuffer().w() <= 320) {
    window = glfwCreateWindow(2*g_Chip->framebuffer().w(),
                              2*g_Chip->framebuffer().h(),
                              "Silice verilator framework", NULL, NULL);
  } else {
    window = glfwCreateWindow(g_Chip->framebuffer().w(),
                              g_Chip->framebuffer().h(),
                              "Silice verilator framework", NULL, NULL);
  }
  glfwMakeContextCurrent(window);
  glfwSwapInterval(1);
  // prepare texture
  glGenTextures(1,&g_FBtexture);
  glBindTexture(GL_TEXTURE_2D,g_FBtexture);
  glTexImage2D( GL_TEXTURE_2D,0, GL_RGBA,
                g_Chip->framebuffer().w(),g_Chip->framebuffer().h(),0,
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
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  glOrtho(0.0f, 1.0f, 1.0f, 0.0f, -1.0f, 1.0f);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
  // start simulation in a thread
  std::thread th(simul);
  // enter main loop
  while (!glfwWindowShouldClose(window)) {
    int width, height;
    glfwGetFramebufferSize(window, &width, &height);
    glViewport(0, 0, width, height);
    render();
    glfwSwapBuffers(window);
    glfwPollEvents();
  }
  // terminate
  glfwDestroyWindow(window);
  glfwTerminate();
}

// ----------------------------------------------------------------------------
