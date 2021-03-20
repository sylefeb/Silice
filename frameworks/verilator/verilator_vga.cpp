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
#include <iostream>

#include "VgaChip.h"
#include "sdr_sdram.h"

unsigned int main_time = 0;
double sc_time_stamp()
{
  return main_time;
}

int main(int argc,char **argv)
{
  // Verilated::commandArgs(argc,argv);

  Vtop    *vga_test = new Vtop();

  char foo[1<<18];

  vga_test->clk = 0;

  // we need to step simulation until we get the parameters
  do {

    vga_test->clk = 1 - vga_test->clk;

    vga_test->eval();

  } while ((int)vga_test->video_color_depth == 0);

  VgaChip *vga_chip = new VgaChip((int)vga_test->video_color_depth);

  vluint8_t sdram_flags = 0;
  if ((int)vga_test->sdram_word_width == 8) {
    sdram_flags |= FLAG_DATA_WIDTH_8;
  } else if ((int)vga_test->sdram_word_width == 16) {
    sdram_flags |= FLAG_DATA_WIDTH_16;
  } else if ((int)vga_test->sdram_word_width == 32) {
    sdram_flags |= FLAG_DATA_WIDTH_32;
  } else if ((int)vga_test->sdram_word_width == 64) {
    sdram_flags |= FLAG_DATA_WIDTH_64;
  }
  
  SDRAM* sdr  = new SDRAM(13 /*8192*/, 10 /*1024*/, sdram_flags, NULL); 
                                                                //"sdram.txt");
  vluint64_t sdram_dq = 0;
  
  vluint8_t prev_vga_vs = 0;
  
  while (!Verilated::gotFinish()) {

    vga_test->clk = 1 - vga_test->clk;

    vga_test->eval();

    sdr->eval(main_time,
              vga_test->sdram_clock, 1,
              vga_test->sdram_cs,  vga_test->sdram_ras, vga_test->sdram_cas, vga_test->sdram_we,
              vga_test->sdram_ba,  vga_test->sdram_a,
              vga_test->sdram_dqm, (vluint64_t)vga_test->sdram_dq_o, sdram_dq);

    vga_test->sdram_dq_i = (vga_test->sdram_dq_en) ? vga_test->sdram_dq_o : sdram_dq;

    if (prev_vga_vs == 0 && vga_test->video_vs != 0) {
      static int cnt = 0;
      char str[256];
      snprintf(str,256,"dump_%04d.raw",cnt++);
      sdr->save(str,4*8192*1024*2,0);
    }
    prev_vga_vs = vga_test->video_vs;
    
    vga_chip->eval(
       vga_test->video_clock,
       vga_test->video_vs,vga_test->video_hs,
       vga_test->video_r,vga_test->video_g,vga_test->video_b);

    main_time ++;
  }

  return 0;
}

