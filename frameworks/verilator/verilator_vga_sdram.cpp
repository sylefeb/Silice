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
#include "sdr_sdram.h"

// ----------------------------------------------------------------------------

Vtop    *g_VgaTest = nullptr; // design
VgaChip *g_VgaChip = nullptr; // VGA simulation
SDRAM   *g_SDRAM   = nullptr; // SDRAM simulation

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
  static vluint64_t sdram_dq    = 0; // SDRAM dq bus status
  static vluint8_t  prev_vga_vs = 0; // previous VGA vs synch status
  
  if (Verilated::gotFinish()) {
    exit(0); // verilog request termination
  }

  // update clock
  g_VgaTest->clk = 1 - g_VgaTest->clk;
  // evaluate design
  g_VgaTest->eval();
  // evaluate SDRAM
  g_SDRAM->eval(g_MainTime,
            g_VgaTest->sdram_clock, 1,
            g_VgaTest->sdram_cs,  g_VgaTest->sdram_ras, g_VgaTest->sdram_cas, g_VgaTest->sdram_we,
            g_VgaTest->sdram_ba,  g_VgaTest->sdram_a,
            g_VgaTest->sdram_dqm, (vluint64_t)g_VgaTest->sdram_dq_o, sdram_dq);
  // emulate the inout SDRAM dq bus
  g_VgaTest->sdram_dq_i = (g_VgaTest->sdram_dq_en) ? g_VgaTest->sdram_dq_o : sdram_dq;
  // enable to dump SDRAM in a raw file at each new frame
  if (0) {
    if (prev_vga_vs == 0 && g_VgaTest->video_vs != 0) {
      static int cnt = 0;
      char str[256];
      snprintf(str,256,"dump_%04d.raw",cnt++);
      g_SDRAM->save(str,4*8192*1024*2,0);
    }
  }
  prev_vga_vs = g_VgaTest->video_vs;  
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

  // instantiate the SDRAM
  vluint8_t sdram_flags = 0;
  if ((int)g_VgaTest->sdram_word_width == 8) {
    sdram_flags |= FLAG_DATA_WIDTH_8;
  } else if ((int)g_VgaTest->sdram_word_width == 16) {
    sdram_flags |= FLAG_DATA_WIDTH_16;
  } else if ((int)g_VgaTest->sdram_word_width == 32) {
    sdram_flags |= FLAG_DATA_WIDTH_32;
  } else if ((int)g_VgaTest->sdram_word_width == 64) {
    sdram_flags |= FLAG_DATA_WIDTH_64;
  }
  g_SDRAM = new SDRAM(13 /*8192*/, 10 /*1024*/, sdram_flags, NULL); 
                                                             //"sdram.txt");

  // enter VGA display loop
  vga_display_loop();

  return 0;
}

// ----------------------------------------------------------------------------
