/*

Copyright 2019, (C) Sylvain Lefebvre and contributors
List contributors with: git shortlog -n -s -- <filename>

MIT license

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

(header_2_M)

*/

// SL 2019-10-09

#include "Vtop.h"
#include <limits>

// #define TRACE_FST

#ifdef TRACE_FST
#include "verilated_fst_c.h"
#endif

int main(int argc,char **argv)
{
  // Verilated::commandArgs(argc,argv);

  // instantiate design
  Vtop    *bare_test = new Vtop();

#ifdef TRACE_FST
  VerilatedFstC *trace = new VerilatedFstC();
  Verilated::traceEverOn(true);
  bare_test->trace(trace, std::numeric_limits<int>::max());
  trace->open("trace.fst");
  int timestamp = 0;
#endif

  while (!Verilated::gotFinish()) {

    // raise clock
    bare_test->clk = 1;
    // evaluate design
    bare_test->eval();
    // trace
#ifdef TRACE_FST
    trace->dump(timestamp++);
#endif
    // lower clock
    bare_test->clk = 0;
    // evaluate design
    bare_test->eval();
    // trace
#ifdef TRACE_FST
    trace->dump(timestamp++);
#endif
  }

#ifdef TRACE_FST
  trace->close();
#endif

  return 0;
}
