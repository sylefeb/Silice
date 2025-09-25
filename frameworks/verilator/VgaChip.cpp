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
// Sylvain Lefebvre 2019-09-26

#include "VgaChip.h"

// ----------------------------------------------------------------------------

VgaChip::VgaChip(int color_depth)
{
  m_color_depth = color_depth;
}

// ----------------------------------------------------------------------------

void VgaChip::set640x480()
{
  m_framebuffer  = LibSL::Image::ImageRGBA(640,480);
  m_h_res        = 640;
  m_h_bck_porch  = 48;
  m_v_res        = 480;
  m_v_bck_porch  = 33;
}

// ----------------------------------------------------------------------------

void VgaChip::set800x600()
{
  m_framebuffer  = LibSL::Image::ImageRGBA(800,600);
  m_h_res        = 800;
  m_h_bck_porch  = 128;
  m_v_res        = 600;
  m_v_bck_porch  = 22;
}

// ----------------------------------------------------------------------------

void VgaChip::set1024x768()
{
  m_framebuffer  = LibSL::Image::ImageRGBA(1024,768);
  m_h_res        = 1024;
  m_h_bck_porch  = 160;
  m_v_res        = 768;
  m_v_bck_porch  = 29;
}

// ----------------------------------------------------------------------------

void VgaChip::set1280x960()
{
  m_framebuffer  = LibSL::Image::ImageRGBA(1280,960);
  m_h_res        = 1280;
  m_h_bck_porch  = 216;
  m_v_res        = 960;
  m_v_bck_porch  = 30;
}

// ----------------------------------------------------------------------------

void VgaChip::set1920x1080()
{
  m_framebuffer  = LibSL::Image::ImageRGBA(1920,1080);
  m_h_res        = 1920;
  m_h_bck_porch  = 328;
  m_v_res        = 1080;
  m_v_bck_porch  = 32;
}

// ----------------------------------------------------------------------------

void VgaChip::setResolution(int w,int h)
{
  if (w == 1920 && h == 1080) {
    set1920x1080();
  } else if (w == 1280 && h == 960) {
    set1280x960();
  } else if (w == 1024 && h == 768) {
    set1024x768();
  } else if (w == 800 && h == 600) {
    set800x600();
  } else if (w == 640 && h == 480) {
    set640x480();
  } else {
    fprintf(stderr,"[set_vga_resolution] error, resolution %dx%d is not supported\n",w,h);
    exit (-1);
  }
}

// ----------------------------------------------------------------------------

VgaChip::~VgaChip()
{

}

// ----------------------------------------------------------------------------

void VgaChip::eval(
            vluint8_t  clk,
            vluint8_t  vs,
            vluint8_t  hs,
            vluint8_t  red,
            vluint8_t  green,
            vluint8_t  blue)
{
  if (!ready()) {
    return;
  }
  if (clk && !m_prev_clk) {
    // horizontal synch
    if (!hs) {
      m_h_coord = 0;
    }
    // vertical synch
    if (!vs) {
      m_v_coord = 0;
    }
    // active area?
    bool active = (m_v_coord >= m_v_bck_porch) && (m_v_coord < m_v_bck_porch + m_v_res)
               && (m_h_coord >= m_h_bck_porch) && (m_h_coord < m_h_bck_porch + m_h_res);
    if (active) {
      int x = m_h_coord - m_h_bck_porch;
      int y = m_v_coord - m_v_bck_porch;
      m_framebuffer.pixel(x,y) = LibSL::Math::v4b(
        red   << (8-m_color_depth),
        green << (8-m_color_depth),
        blue  << (8-m_color_depth),
        255);
      if (x == m_h_res - 1 && y == m_v_res - 1) {
        // save image
#if 1   // TODO make this a command line switch
        saveImage("last_frame.tga",&m_framebuffer);
#else
        static int cnt = 0;
        char str[256];
        snprintf(str,256,"frame_%04d.tga",cnt++);
        saveImage(str,&m_framebuffer);
#endif
      }
    }
    // update horizontal coordinate
    if (hs) {
      ++ m_h_coord;
    }
    // update vertical coordinate
    if (vs) {
      if (m_h_coord == m_h_bck_porch + m_h_res) {
        ++ m_v_coord;
        m_framebuffer_changed = true;
      }
    }
  }
  m_prev_clk = clk;
}

// ----------------------------------------------------------------------------

bool VgaChip::framebufferChanged()
{
  bool changed = m_framebuffer_changed;
  m_framebuffer_changed = false;
  return changed;
}

// ----------------------------------------------------------------------------
