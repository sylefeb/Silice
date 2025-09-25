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

#include "ParallelScreen.h"

// ----------------------------------------------------------------------------

ParallelScreen::ParallelScreen(e_Driver driver,int width,int height)
  : m_driver(driver)
{
  m_framebuffer = LibSL::Image::ImageRGBA(width,height);
  set_idle();
}

// ----------------------------------------------------------------------------

ParallelScreen::~ParallelScreen()
{

}

// ----------------------------------------------------------------------------

void ParallelScreen::set_idle()
{
  switch (m_driver)
  {
    case ILI9341:
      m_command   = std::bind( &ParallelScreen::cmd_idle_ILI9341, this ); break;
    default: {
      fprintf(stderr,"ParallelScreen error, unknown driver mode %d\n",m_driver);
      exit(-1);
    }
  }
}

// ----------------------------------------------------------------------------

void ParallelScreen::eval(
            vluint8_t  clk,
            vluint32_t data, // incoming data
            vluint8_t  rs,   // data or command
            vluint8_t  csn,  // select
            vluint8_t  resn  // reset
) {
  if (!resn) {
    // reset state
  } else if (!csn) { // chip selected
    if (!clk && m_prev_clk) {
      // store byte
      m_byte = data & 255;
      // data or command
      m_dc   = rs;
      // process
      m_command();
    }
  }
  m_prev_clk = clk;
}

// ----------------------------------------------------------------------------

void ParallelScreen::cmd_idle_ILI9341()
{
  m_step = 0;
  if (!m_dc) {
    fprintf(stdout,"command: %x\n", m_byte);
    switch (m_byte) {
      case 0x2A:
        m_command = std::bind( &ParallelScreen::cmd_start_end, this, &m_y_start, &m_y_end, 2);
        break;
      case 0x2B:
        m_command = std::bind( &ParallelScreen::cmd_start_end, this, &m_x_start, &m_x_end, 2);
        break;
      case 0x2C:
        m_command = std::bind( &ParallelScreen::cmd_write_ram, this );
        break;
      case 0x3A:
        m_command = std::bind( &ParallelScreen::cmd_mode_ILI9341, this );
        break;
      case 0x36:
        m_command = std::bind( &ParallelScreen::cmd_madctl_ILI9341, this );
        break;
      default:
        break;
    }
  }
}

// ----------------------------------------------------------------------------

void ParallelScreen::cmd_mode_ILI9341()
{
  if (m_byte != 0x55) {
    fprintf(stderr,"ParallelScreen error, only supported mode on ILI9341 is 16 bits per pixel (got 0x%x, expected 0x55)\n");
    exit(-1);
  }
  set_idle();
}

// ----------------------------------------------------------------------------

void ParallelScreen::cmd_madctl_ILI9341()
{
  if ((m_byte & 0x20) != 0) {
    fprintf(stdout,"screen in row major mode\n");
    m_row_major = true;
  } else {
    m_row_major = false;
  }
  set_idle();
}

// ----------------------------------------------------------------------------

void ParallelScreen::cmd_start_end(int *p_start,int *p_end,int nbytes)
{
  fprintf(stdout,"cmd_start_end, byte: %x (step:%d)\n",m_byte,m_step);
  if (m_step == 0) {
    if (nbytes == 2) {
      *p_start  = m_byte << 8;
    } else {
      *p_start  = m_byte;
      *p_end    = 0;
      m_step += 2;
    }
  } else if (m_step == 1) {
    *p_start |= m_byte;
  } else if (m_step == 2) {
    *p_end    = m_byte << 8;
  } else {
    *p_end   |= m_byte;
    fprintf(stdout,"start_end: %d => %d\n", *p_start, *p_end);
    set_idle();
  }
  m_step = m_step + 1;
}

// ----------------------------------------------------------------------------

void ParallelScreen::cmd_write_ram()
{
  if (!m_dc) {
    // command
    cmd_idle_ILI9341();
    return;
  }
  if (m_step == 0) {
    // first time
    m_x_cur = m_x_start;
    m_y_cur = m_y_start;
    m_step = 1;
  }
  // 5-6-5
  if (m_step == 1) {
    m_rgb[1] = (m_byte & 7);
    m_rgb[2] = (m_byte >> 3);
  } else {
    m_rgb[1] = (m_rgb[1] << 3) | (m_byte >> 5);
    m_rgb[0] = (m_byte & 31);
    //fprintf(stdout,"565 x %d, y %d rgb:%02x,%02x,%02x\n",
    //        m_x_cur,m_y_cur,(int)m_rgb[0],(int)m_rgb[1],(int)m_rgb[2]);
    m_rgb[0] <<= 3;      m_rgb[1] <<= 2;      m_rgb[2] <<= 3;    m_rgb[3]=255;
    m_framebuffer.pixel<LibSL::Memory::Array::Wrap>(
                                m_x_cur,m_y_cur) = m_rgb;
    m_framebuffer_changed = true; // update every pixel
  }
  ++m_step;
  if (m_step > 2) {
    // move to next pixel
    m_step = 1;
    if (!m_row_major) {
      ++ m_y_cur;
      if (m_y_cur > m_y_end) {
        m_y_cur = m_y_start;
        ++ m_x_cur;
        if (m_x_cur > m_x_end) {
          m_x_cur = m_x_start;
          m_framebuffer_changed = true;
#if 0
          static int cnt = 0;
          char str[256];
          snprintf(str,256,"frame_%04d.tga",cnt++);
          saveImage(str,&m_framebuffer);
#endif
        }
      }
    } else {
      ++ m_x_cur;
      if (m_x_cur > m_y_end) {
        m_x_cur = m_y_start;
        ++ m_y_cur;
        if (m_y_cur > m_x_end) {
          m_y_cur = m_x_start;
          m_framebuffer_changed = true;
#if 0
          static int cnt = 0;
          char str[256];
          snprintf(str,256,"frame_%04d.tga",cnt++);
          saveImage(str,&m_framebuffer);
#endif
        }
      }
    }
  }
}

// ----------------------------------------------------------------------------

bool ParallelScreen::framebufferChanged()
{
  bool changed = m_framebuffer_changed;
  m_framebuffer_changed = false;
  return changed;
}

// ----------------------------------------------------------------------------
