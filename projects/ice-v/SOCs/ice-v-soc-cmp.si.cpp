// SL 2022-05-13
// -------------------------------------------------------
//
// Custom verilator framework for comparing the ice-v, the
// ice-v-conveyor and the ice-v-swirl
//
// NOTE: call to rdcycle will generate errors, as CPU speed differ.
//
// The CPU are instrumented with a custom callback (cpu_retires),
// see also ICEV_VERILATOR_TRACE in CPUs.
// CPU Ids: 1:ice-v, 2:ice-v-conveyor, 3:ice-v-swirl
//
// -------------------------------------------------------

#include "Vtop.h"
#include <limits>
#include <iostream>
#include <list>

// -------------------------------------------------------

// record for each retired instruction
typedef struct s_retired_instr
{
  unsigned int pc; unsigned int instr;
  unsigned int rd; unsigned int val;
} t_retired_instr;

// comparison operator for struct above
bool operator==(const t_retired_instr& ri0,const t_retired_instr& ri1)
{
	return ri0.pc == ri1.pc && ri0.instr == ri1.instr
	    && ri0.rd == ri1.rd && ri0.val   == ri1.val;
}

// tracks retired instructions for all three CPUs
std::list< t_retired_instr > retired[3];
int num_retired[3] = {0,0,0};
int num_checks = 0;

// cpu names
const char *cpu_names[3] = {"ice-v","conveyor","swirl"};

// check that CPUs remain in synch, compute performance indicator
void check_and_synch()
{
	// if one of the CPU list is empty, skip this call
	for (int i = 0 ; i < 3 ; ++i) {
		if (retired[i].empty()) return;
	}
	// verify coherence
	if (retired[0].front() == retired[1].front()
	&&  retired[0].front() == retired[2].front()) {
		for (int i = 0 ; i < 3 ; ++i) {
			retired[i].pop_front();
		}
	} else {
		// not good ...
		fprintf(stderr,"\n>>>> [ERROR] CPUs have diverged <<<<\n");
		// print
		for (int i = 0 ; i < 3 ; ++i) {
			const auto ri = retired[i].front();
			fprintf(stderr,"[%s] @%03x %08x",cpu_names[i],ri.pc,ri.instr);
			if (ri.rd != 0) {
				fprintf(stderr," reg[%2d]=%08x",ri.rd,ri.val);
			} else {
				fprintf(stderr,"                 ");
			}
			fprintf(stderr," ");
		}
		fprintf(stderr,"\n");
		exit (-1);
	}
	// regularly print number of retired instruction
	if ((num_checks & 1023) == 1023) {
		int max_retired = 0;
		for (int i = 0 ; i < 3 ; ++i) {
			if (num_retired[i] > max_retired) {
				max_retired = num_retired[i];
			}
		}
		for (int i = 0 ; i < 3 ; ++i) {
			fprintf(stderr,"[%s] %3.0f %%    ",cpu_names[i],
			   (double)num_retired[i] * 100.0 / (double)max_retired);
		}
		fprintf(stderr,"\n");
	}
	++ num_checks;
}

// callback by each CPU when an instruction is retired
void cpu_retires(int id,unsigned int pc,unsigned int instr,
                        unsigned int rd,unsigned int val)
{
	t_retired_instr ri;
	ri.pc = pc; ri.instr = instr;
	ri.rd = rd; ri.val   = val;
	retired[id-1].push_back(ri);
	++ num_retired[id-1];
	check_and_synch();
}

// main, instantiate the design from Verilator and runs the clock
int main(int argc,char **argv)
{
	// instantiate design
	Vtop    *bare_test = new Vtop();

	bare_test->clk = 0;
	while (!Verilated::gotFinish()) {

		// step design
		bare_test->clk = 1 - bare_test->clk;
		bare_test->eval();

	}

	return 0;
}
