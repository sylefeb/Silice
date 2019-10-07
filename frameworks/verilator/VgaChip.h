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
  
  void eval(vluint64_t cycle, 
            vluint8_t  clk,
            vluint8_t  vs,   
            vluint8_t  hs,   
            vluint8_t  red,  
            vluint8_t  green, 
            vluint8_t  blue);
  
};

