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

#pragma once

#include "verilated.h"

#include <vector>

#include "LibSL/Image/Image.h"
#include "LibSL/Image/ImageFormat_TGA.h"
#include "LibSL/Math/Vertex.h"

/// \brief Isolates the implementation to simplify build
class VgaChip
{
private:

  LibSL::Image::ImageRGBA m_framebuffer;

  int m_color_depth  = 0;

  int m_h_res        = 0;
  int m_h_bck_porch  = 0;
  int m_v_res        = 0;
  int m_v_bck_porch  = 0;

  int m_h_coord = 0;
  int m_v_coord = 0;

  vluint8_t m_prev_clk = 0;

  void set640x480();

public:

  VgaChip(int color_depth);
  ~VgaChip();
  
  void eval(vluint8_t  clk,
            vluint8_t  vs,   
            vluint8_t  hs,   
            vluint8_t  red,  
            vluint8_t  green, 
            vluint8_t  blue);
  
};

