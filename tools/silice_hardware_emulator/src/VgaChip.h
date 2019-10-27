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

#include <LibSL/LibSL.h>

class VideoOut;

/// \brief Isolates the implementation to simplify build
class VgaChip
{
private:

  VideoOut *m_VideoOut = nullptr;
  int       m_W;
  int       m_H;

public:

  VgaChip();
  ~VgaChip();
  
  void step(uint8_t  clk,
            uint8_t  vs,   
            uint8_t  hs,   
            uint8_t  red,  
            uint8_t  green, 
            uint8_t  blue);
  
  int          w() const { return m_W; }
  int          h() const { return m_H; }

  bool                        frameBufferChanged() const;
  LibSL::Image::ImageRGBA_Ptr frameBuffer();

};

