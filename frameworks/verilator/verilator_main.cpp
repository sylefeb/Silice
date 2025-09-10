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
// SL 2023-07-27

#include "Vtop.h"
#include "display.h"

// ----------------------------------------------------------------------------

Vtop           *g_Design    = nullptr; // design
#ifdef VGA
#include "VgaChip.h"
VgaChip        *g_VgaChip   = nullptr; // VGA simulation
#endif
#ifdef SPISCREEN
#include "SPIScreen.h"
SPIScreen      *g_SPIScreen = nullptr; // SPI screen simulation
#endif
#ifdef PARALLEL_SCREEN
#include "ParallelScreen.h"
ParallelScreen *g_ParallelScreen = nullptr; // parallel screen simulation
#endif
#ifdef SDRAM
#include "sdr_sdram.h"
SimulSDRAM     *g_SDRAM     = nullptr; // SDRAM simulation
#endif
#ifdef PWM_AUDIO
#include "PWMAudio.h"
PWMAudio       *g_AudioChip   = nullptr; // Audio simulation
#endif

// ----------------------------------------------------------------------------

unsigned int g_MainTime = 0;
double sc_time_stamp()
{
  return g_MainTime;
}

// ----------------------------------------------------------------------------

int g_Width  = 0;
int g_Height = 0;

// callback to set vga resolution
void set_vga_resolution(int w,int h)
{
  fprintf(stderr,"[set_vga_resolution] %dx%d\n",w,h);
  g_Width  = w;
  g_Height = h;
}

// ----------------------------------------------------------------------------

// steps the simulation
int step()
{

  if (Verilated::gotFinish()) {
    return 0; // verilog request termination
  }

  // update clock
  g_Design->clk = 1 - g_Design->clk;

  // evaluate design
  g_Design->eval();

#ifdef VGA
  // evaluate VGA
  static vluint8_t  prev_vga_vs = 0; // previous VGA vs synch status
  prev_vga_vs = g_Design->video_vs;
  g_VgaChip->eval(
      g_Design->video_clock,
      g_Design->video_vs,g_Design->video_hs,
      g_Design->video_r, g_Design->video_g,g_Design->video_b);
#endif

#ifdef SPISCREEN
  // evaluate screen
  g_SPIScreen->eval(
      g_Design->spiscreen_clk,
      g_Design->spiscreen_mosi, g_Design->spiscreen_dc,
      g_Design->spiscreen_csn,  g_Design->spiscreen_resn);
#endif

#ifdef PARALLEL_SCREEN
  // evaluate screen
  g_ParallelScreen->eval(
      g_Design->prlscreen_clk,
      g_Design->prlscreen_d,   g_Design->prlscreen_rs,
      g_Design->prlscreen_csn, g_Design->prlscreen_resn);
#endif

#ifdef SDRAM
  // evaluate SDRAM
  static vluint64_t sdram_dq    = 0; // SDRAM dq bus status
  g_SDRAM->eval(g_MainTime,
            g_Design->sdram_clock, 1,
            g_Design->sdram_cs,  g_Design->sdram_ras, g_Design->sdram_cas, g_Design->sdram_we,
            g_Design->sdram_ba,  g_Design->sdram_a,
            g_Design->sdram_dqm, (vluint64_t)g_Design->sdram_dq_o, sdram_dq);
  // emulate the inout SDRAM dq bus
  g_Design->sdram_dq_i = (g_Design->sdram_dq_en) ? g_Design->sdram_dq_o : sdram_dq;
  #ifdef VGA
  // enable to dump SDRAM in a raw file at each new frame
  if (0) {
    if (prev_vga_vs == 0 && g_Design->video_vs != 0) {
      static int cnt = 0;
      char str[256];
      snprintf(str,256,"dump_%04d.raw",cnt++);
      g_SDRAM->save(str,4*8192*1024*2,0);
    }
  }
  #endif
#endif

#ifdef PWM_AUDIO
  g_AudioChip->eval(g_Design->clk, g_Design->pwm_audio);
#endif

  // increment time
  g_MainTime ++;

  return 1; // keep going
}

// ----------------------------------------------------------------------------

int main(int argc,char **argv)
{
  Verilated::commandArgs(argc,argv);

  // unbuffered stdout and stderr
  setbuf(stdout, NULL);
  setbuf(stderr, NULL);

  // instantiate design
  g_Design = new Vtop();
  g_Design->clk = 0;

  // we need to step simulation until we get
  // the parameters set from design signals
  int iter = 0;
  do {
    g_Design->clk = 1 - g_Design->clk;
    g_Design->eval();
  } while (
      (0
#ifdef VGA
      || ((int)g_Design->video_color_depth == 0 || g_Width == 0)
#endif
#ifdef SPISCREEN
      || ((int)g_Design->spiscreen_driver == 0)
#endif
#ifdef PARALLEL_SCREEN
      || ((int)g_Design->prlscreen_driver == 0)
#endif
      ) && (++iter<1024));

#ifdef VGA
  // instantiate the VGA chip
  g_VgaChip = new VgaChip((int)g_Design->video_color_depth);
  // set resolution
  if (g_Width == 0) {
    fprintf(stderr,"error, no resolution information was received "
                   "(set_vga_resolution not called from design)\n");
    exit(-1);
  }
  g_VgaChip->setResolution(g_Width,g_Height);
#endif

#ifdef SPISCREEN
  if (g_Design->spiscreen_driver == SPIScreen::SSD1351) {
    fprintf(stdout,"SPIScreen SSD1351, %dx%d\n",g_Design->spiscreen_width,
                                                g_Design->spiscreen_height);
  } else if (g_Design->spiscreen_driver == SPIScreen::ST7789) {
    fprintf(stdout,"SPIScreen ST7789, %dx%d\n",g_Design->spiscreen_width,
                                               g_Design->spiscreen_height);
  } else if (g_Design->spiscreen_driver == SPIScreen::ILI9351) {
    fprintf(stdout,"SPIScreen ILI9351, %dx%d\n",g_Design->spiscreen_width,
                                                g_Design->spiscreen_height);
  } else {
    fprintf(stdout,"Unknown SPIScreen driver, known values are:\n");
    fprintf(stdout,"   - [%d] SSD1351\n",SPIScreen::SSD1351);
    fprintf(stdout,"   - [%d] ST7789\n", SPIScreen::ST7789);
    fprintf(stdout,"   - [%d] ILI9351\n",SPIScreen::ILI9351);
    exit(-1);
  }
  // instantiate the screen
  g_SPIScreen = new SPIScreen(
      (SPIScreen::e_Driver)g_Design->spiscreen_driver,
      g_Design->spiscreen_width,
      g_Design->spiscreen_height);
#endif

#ifdef PARALLEL_SCREEN
  if (g_Design->prlscreen_driver == ParallelScreen::ILI9341) {
    fprintf(stdout,"ParallelScreen ILI9341, %dx%d\n",g_Design->prlscreen_width,
                                                g_Design->prlscreen_height);
  } else {
    fprintf(stdout,"Unknown ParallelScreen driver, known values are:\n");
    fprintf(stdout,"   - [%d] ILI9341\n",ParallelScreen::ILI9341);
    exit(-1);
  }
  // instantiate the screen
  g_ParallelScreen = new ParallelScreen(
      (ParallelScreen::e_Driver)g_Design->prlscreen_driver,
      g_Design->prlscreen_width,
      g_Design->prlscreen_height);
#endif

#ifdef SDRAM
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
  g_SDRAM = new SimulSDRAM(13 /*8192*/, 10 /*1024*/, sdram_flags, NULL);
                                                             //"sdram.txt");
#endif

#ifdef PWM_AUDIO
  // instantiate audio chip
  g_AudioChip = new PWMAudio(/*TODO*/25.0);
#endif

  bool has_display_loop = false;
  // enter display loop if any
#ifdef VGA
  display_loop(g_VgaChip);
#endif
#ifdef SPISCREEN
  display_loop(g_SPIScreen);
#endif
#ifdef PARALLEL_SCREEN
  display_loop(g_ParallelScreen);
#endif

  // loop here if there is no display
  if (!has_display_loop) {
    simul();
  }

  return 0;
}

// ----------------------------------------------------------------------------
