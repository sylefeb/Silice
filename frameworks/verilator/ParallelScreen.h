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
// Sylvain Lefebvre 2023-07-27

#pragma once

#include "verilated.h"

#include <vector>
#include <functional>

#include "LibSL/Image/Image.h"
#include "LibSL/Image/ImageFormat_TGA.h"
#include "LibSL/Math/Vertex.h"

#include "display.h"

/// \brief Isolates the implementation to simplify build
class ParallelScreen : public DisplayChip
{
public:

  enum e_Driver {Unknown=0,ILI9341=1};

private:

  LibSL::Image::ImageRGBA m_framebuffer;
  bool                    m_framebuffer_changed = false;

  e_Driver                m_driver;
  vluint8_t               m_prev_clk;

  int                     m_width = 8; // only case supported for now

  bool                    m_dc = false;
  int                     m_byte = 0;
  int                     m_step = 0;

  int                     m_x_start = 0;
  int                     m_x_end   = 0;
  int                     m_y_start = 0;
  int                     m_y_end   = 0;

  int                     m_x_cur   = 0;
  int                     m_y_cur   = 0;
  
  bool                    m_row_major = false;

  LibSL::Math::v4b        m_rgb;

  std::function<void()>   m_command;

  void set_idle();

  void cmd_idle_ILI9341();
  void cmd_mode_ILI9341();
  void cmd_madctl_ILI9341();

  void cmd_start_end(int *p_start,int *p_end,int nbytes);
  void cmd_write_ram();

public:

  ParallelScreen(e_Driver driver,int width,int height);
  ~ParallelScreen();

  void eval(vluint8_t  clk,  // wrn
            vluint32_t data, // incoming data
            vluint8_t  rs,   // data or command
            vluint8_t  csn,  // select
            vluint8_t  resn  // reset
            );

  LibSL::Image::ImageRGBA& framebuffer() override { return m_framebuffer; }

  bool framebufferChanged() override;

  bool ready() override { return true; }
};
