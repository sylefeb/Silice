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
// SL 2021-10-11

#include "Vtop.h"
#include "SPIScreen.h"
#include "display.h"

// ----------------------------------------------------------------------------

Vtop      *g_Design = nullptr; // design
SPIScreen *g_Screen = nullptr; // SPI screen simulation

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
  if (Verilated::gotFinish()) {
    exit(0); // verilog request termination
  }

  // update clock
  g_Design->clk = 1 - g_Design->clk;
  // evaluate design
  g_Design->eval();
  // evaluate screen
  g_Screen->eval(
      g_Design->oled_clk,
      g_Design->oled_mosi, g_Design->oled_dc,
      g_Design->oled_csn,  g_Design->oled_resn);
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
  // TODO get screen driver, width, height
  //do {
  //  g_Design->clk = 1 - g_Design->clk;
  //  g_Design->eval();
  //} while ((int)g_Design->video_color_depth == 0);

  // instantiate the screen
  g_Screen = new SPIScreen(SPIScreen::ST7789,320,240);

  // enter display loop
  display_loop(g_Screen);

  return 0;
}

// ----------------------------------------------------------------------------
