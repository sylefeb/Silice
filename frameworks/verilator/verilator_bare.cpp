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
// SL 2019-10-09

#include "Vtop.h"
#include <iostream>

int main(int argc,char **argv)
{

  // Verilated::commandArgs(argc,argv);

  Vtop    *bare_test = new Vtop("");

  while (!Verilated::gotFinish()) {

    bare_test->clk = 1;

    bare_test->eval();

    bare_test->clk = 0;

    bare_test->eval();

  }

  return 0;
}

