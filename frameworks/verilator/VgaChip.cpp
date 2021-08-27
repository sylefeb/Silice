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
  set640x480();
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
          saveImage("last_frame.tga",&m_framebuffer);
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
