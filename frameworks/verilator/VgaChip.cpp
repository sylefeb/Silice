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
#include "video_out.h"

VgaChip::VgaChip()
{
  m_VideoOut = new VideoOut(
        0/*debug*/,4/*color depth*/,0/*polarity*/,
        640 ,16,96,48,
        480 ,10,2,33,
        "vgaout");
}

VgaChip::~VgaChip()
{
  delete (m_VideoOut);
}

void VgaChip::eval(vluint64_t cycle,
            vluint8_t  clk,
            vluint8_t  vs,
            vluint8_t  hs,
            vluint8_t  red,
            vluint8_t  green,
            vluint8_t  blue)
{
  m_VideoOut->eval_RGB_HV(cycle,clk,vs,hs,red,green,blue);
}

