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
// SL 2021-10-18

#include "Vtop.h"
#include "sdr_sdram.h"

// ----------------------------------------------------------------------------

Vtop    *g_Design = nullptr; // design
SDRAM   *g_SDRAM  = nullptr; // SDRAM simulation

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

  if (Verilated::gotFinish()) {
    exit(0); // verilog request termination
  }

  // update clock
  g_Design->clk = 1 - g_Design->clk;
  // evaluate design
  g_Design->eval();
  // evaluate SDRAM
  g_SDRAM->eval(g_MainTime,
            g_Design->sdram_clock, 1,
            g_Design->sdram_cs,  g_Design->sdram_ras, g_Design->sdram_cas,
            g_Design->sdram_we,  g_Design->sdram_ba,  g_Design->sdram_a,
            g_Design->sdram_dqm, (vluint64_t)g_Design->sdram_dq_o, sdram_dq);
  // emulate the inout SDRAM dq bus
  g_Design->sdram_dq_i = (g_Design->sdram_dq_en) ? g_Design->sdram_dq_o
                                                 : sdram_dq;
  // increment time
  g_MainTime ++;
}

// ----------------------------------------------------------------------------

int main(int argc,char **argv)
{
  // Verilated::commandArgs(argc,argv);

  // instantiate design
  g_Design = new Vtop();
  g_Design->clk = 0;

  // we need to step simulation until we get
  // the parameters set from design signals
  do {
    g_Design->clk = 1 - g_Design->clk;
    g_Design->eval();
  } while ((int)g_Design->sdram_word_width == 0);

  // instantiate the SDRAM
  vluint8_t sdram_flags = 0;
  if ((int)g_Design->sdram_word_width == 8) {
    sdram_flags |= FLAG_DATA_WIDTH_8;
  } else if ((int)g_Design->sdram_word_width == 16) {
    sdram_flags |= FLAG_DATA_WIDTH_16;
  } else if ((int)g_Design->sdram_word_width == 32) {
    sdram_flags |= FLAG_DATA_WIDTH_32;
  } else if ((int)g_Design->sdram_word_width == 64) {
    sdram_flags |= FLAG_DATA_WIDTH_64;
  }
  g_SDRAM = new SDRAM(13 /*8192*/, 10 /*1024*/, sdram_flags, NULL);
                                                            //"sdram.txt");

  // simulation loop
  while (1) {
    step();
  }

  return 0;
}

// ----------------------------------------------------------------------------
