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

int main(int argc,char **argv)
{
  // Verilated::commandArgs(argc,argv);

  // instantiate design
  Vtop    *bare_test = new Vtop();

  while (!Verilated::gotFinish()) {

    // raise clock
    bare_test->clk = 1;
    // evaluate design
    bare_test->eval();
    // lower clock
    bare_test->clk = 0;
    // evaluate design
    bare_test->eval();

    if (0) { // enable to trace the status of LEDs 
      fprintf(stderr,"leds:%d\n",bare_test->leds);
    }
  }

  return 0;
}

