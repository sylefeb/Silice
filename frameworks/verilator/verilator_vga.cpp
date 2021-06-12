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
// SL 2019-09-23

#include "Vtop.h"

#include "VgaChip.h"

Vtop    *g_VgaTest = nullptr;
VgaChip *g_VgaChip = nullptr;

unsigned int g_MainTime = 0;
double sc_time_stamp()
{
  return g_MainTime;
}

void step()
{
  if (Verilated::gotFinish()) {
    exit (0);
  }

  g_VgaTest->clk = 1 - g_VgaTest->clk;

  g_VgaTest->eval();

  g_VgaChip->eval(
      g_VgaTest->video_clock,
      g_VgaTest->video_vs,g_VgaTest->video_hs,
      g_VgaTest->video_r, g_VgaTest->video_g,g_VgaTest->video_b);

  g_MainTime ++;
}

int main(int argc,char **argv)
{
  // Verilated::commandArgs(argc,argv);

  // instantiate design
  g_VgaTest = new Vtop();
  g_VgaTest->clk = 0;
  // we need to step simulation until we get the parameters
  do {
    g_VgaTest->clk = 1 - g_VgaTest->clk;
    g_VgaTest->eval();
  } while ((int)g_VgaTest->video_color_depth == 0);

  // instantiate VGA chip
  g_VgaChip = new VgaChip((int)g_VgaTest->video_color_depth);

  while (1) { step(); }

  return 0;
}

