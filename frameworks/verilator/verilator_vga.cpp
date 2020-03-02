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

int main(int argc,char **argv)
{

  Verilated::commandArgs(argc,argv);

  VgaChip *vga_chip = new VgaChip();
  Vvga    *vga_test = new Vvga();

  vga_test->clk = 0;

  while (!Verilated::gotFinish()) {

    vga_test->clk = 1 - vga_test->clk;

    vga_test->eval();

    vga_chip->eval(vga_test->vga_clock,vga_test->vga_vs,vga_test->vga_hs,vga_test->vga_r,vga_test->vga_g,vga_test->vga_b);

  }

  return 0;
}

