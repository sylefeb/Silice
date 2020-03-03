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

#include "Vvga.h"
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

  Verilated::commandArgs(argc,argv);

  VgaChip *vga_chip = new VgaChip();
  Vvga    *vga_test = new Vvga();

  // setup for a mt48lc32m8a2 // 8 M x 8 bits x 4 banks (256 MB),
  // 67,108,864-bit banks is organized as 8192 rows by 1024 columns by 8 bits
  // this matches the Mojo Alchitry board with SDRAM shield
  vluint8_t sdram_flags = FLAG_DATA_WIDTH_8; // | FLAG_BANK_INTERLEAVING | FLAG_BIG_ENDIAN;
  SDRAM* sdr  = new SDRAM(13 /*8192*/, 10 /*1024*/, sdram_flags, "sdram.txt");
  vluint64_t sdram_dq_i = 0,sdram_dq_o = 0;
  
  vga_test->clk = 0;

  while (!Verilated::gotFinish()) {

    vga_test->clk = 1 - vga_test->clk;

    vga_test->eval();

    sdr->eval(main_time,
              vga_test->sdram_clock, 1,
              vga_test->sdram_cs,  vga_test->sdram_ras, vga_test->sdram_cas, vga_test->sdram_we,
              vga_test->sdram_ba,  vga_test->sdram_a,
              vga_test->sdram_dqm, sdram_dq_i, sdram_dq_o);
    vga_test->sdram_dq = (vga_test->sdram_dq_en) ? sdram_dq_i : sdram_dq_o;
    
    vga_chip->eval(vga_test->vga_clock,vga_test->vga_vs,vga_test->vga_hs,vga_test->vga_r,vga_test->vga_g,vga_test->vga_b);

    main_time ++;
  }

  return 0;
}

