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

class VideoOut;

/// \brief Isolates the implementation to simplify build
class VgaChip
{
private:

  VideoOut *m_VideoOut = nullptr;

public:

  VgaChip();
  ~VgaChip();
  
  void eval(vluint8_t  clk,
            vluint8_t  vs,   
            vluint8_t  hs,   
            vluint8_t  red,  
            vluint8_t  green, 
            vluint8_t  blue);
  
};

