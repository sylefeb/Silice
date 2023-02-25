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
// Sylvain Lefebvre 2019-09-26

#pragma once

#include "verilated.h"

#include <vector>

#include "LibSL/Image/Image.h"
#include "LibSL/Image/ImageFormat_TGA.h"
#include "LibSL/Math/Vertex.h"

#include "display.h"

/// \brief Isolates the implementation to simplify build
class VgaChip : public DisplayChip
{
private:

  LibSL::Image::ImageRGBA m_framebuffer;

  int m_color_depth  = 0;

  int m_h_res        = 0;
  int m_h_bck_porch  = 0;
  int m_v_res        = 0;
  int m_v_bck_porch  = 0;

  int m_h_coord = 0;
  int m_v_coord = 0;

  vluint8_t m_prev_clk = 0;

  bool m_framebuffer_changed = false;

  void set640x480();
  void set800x600();
  void set1024x768();
  void set1280x960();
  void set1920x1080();

public:

  VgaChip(int color_depth);
  ~VgaChip();

  void eval(vluint8_t  clk,
            vluint8_t  vs,
            vluint8_t  hs,
            vluint8_t  red,
            vluint8_t  green,
            vluint8_t  blue);

  LibSL::Image::ImageRGBA& framebuffer() override { return m_framebuffer; }

  bool framebufferChanged() override;
  bool ready() override { return m_h_res != 0; }

  void setResolution(int w,int h);

};
