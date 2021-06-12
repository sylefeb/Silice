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
        static int num = 0;
        saveImage(LibSL::CppHelpers::sprint("vga_%04d.tga",num++),&m_framebuffer);
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
