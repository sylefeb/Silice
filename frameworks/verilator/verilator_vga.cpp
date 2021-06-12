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
#include "vga_display.h"

// ----------------------------------------------------------------------------

Vtop    *g_VgaTest = nullptr; // design
VgaChip *g_VgaChip = nullptr; // VGA simulation

// ----------------------------------------------------------------------------

unsigned int g_MainTime = 0;

double sc_time_stamp()
{
  return g_MainTime;
}

// ----------------------------------------------------------------------------

// steps the simulation
void step()
{
  if (Verilated::gotFinish()) {
    exit(0); // verilog request termination
  }

  // update clock
  g_VgaTest->clk = 1 - g_VgaTest->clk;
  // evaluate design
  g_VgaTest->eval();
  // evaluate VGA
  g_VgaChip->eval(
      g_VgaTest->video_clock,
      g_VgaTest->video_vs,g_VgaTest->video_hs,
      g_VgaTest->video_r, g_VgaTest->video_g,g_VgaTest->video_b);
  // increment time
  g_MainTime ++;
}

// ----------------------------------------------------------------------------

int main(int argc,char **argv)
{
  // Verilated::commandArgs(argc,argv);

  // instantiate design
  g_VgaTest = new Vtop();
  g_VgaTest->clk = 0;
  
  // we need to step simulation until we get
  // the parameters set from design signals
  do {
    g_VgaTest->clk = 1 - g_VgaTest->clk;
    g_VgaTest->eval();
  } while ((int)g_VgaTest->video_color_depth == 0);

  // instantiate the VGA chip
  g_VgaChip = new VgaChip((int)g_VgaTest->video_color_depth);

  // enter VGA display loop
  vga_display_loop();

  return 0;
}

// ----------------------------------------------------------------------------
