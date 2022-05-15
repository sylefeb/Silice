// SL 2022-05-13

#include "Vtop.h"
#include <limits>
#include <iostream>

void cpu_retires(int id,unsigned int pc,unsigned int instr,unsigned int rd,unsigned int val)
{
	fprintf(stdout,"[CPU%d] @%03x %08x",id,pc,instr);
	if (rd != 0) {
		fprintf(stdout," reg[%2d]=%08x",rd,val);
	}
	fprintf(stdout,"\n",instr);
}

int main(int argc,char **argv)
{
  // instantiate design
  Vtop    *bare_test = new Vtop();

	int iter = 0;
  while (!Verilated::gotFinish() && ++iter < 64) {

		// step design
		bare_test->clk = 1;
		bare_test->eval();
		bare_test->clk = 0;
		bare_test->eval();

  }

  return 0;
}
