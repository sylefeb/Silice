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
// Sylvain Lefebvre 2021-10-11

#include "SPIScreen.h"

// ----------------------------------------------------------------------------

SPIScreen::SPIScreen(e_Driver driver,int width,int height)
  : m_driver(driver)
{
  m_framebuffer = LibSL::Image::ImageRGBA(width,height);
  set_idle();
}

// ----------------------------------------------------------------------------

SPIScreen::~SPIScreen()
{

}

// ----------------------------------------------------------------------------

void SPIScreen::set_idle()
{
  switch (m_driver)
  {
    case SSD1351:
      m_command   = std::bind( &SPIScreen::cmd_idle_SSD1351, this );        break;
    case ILI9351:
    case ST7789:
      m_command   = std::bind( &SPIScreen::cmd_idle_ST7789_ILI9351, this ); break;
    default: {
      fprintf(stderr,"SPIScreen error, unknown driver mode %d\n",m_driver);
      exit(-1);
    }
  }
}

// ----------------------------------------------------------------------------

void SPIScreen::eval(
            vluint8_t clk,
            vluint8_t mosi,
            vluint8_t dc,
            vluint8_t csn,
            vluint8_t resn)
{
  // fprintf(stderr,"csn:%d clk:%d mosi:%d dc:%d resn:%d\n",csn,clk,mosi,dc,resn);
  if (resn == 0) {        // reset?
    m_reading = 0;
  } else if (!csn) { // chip selected
    if (clk && !m_prev_clk) {
      if (m_reading == 0) {
        // start reading
        m_dc   = (dc != 0);
        m_byte = 0;
      }
      // add one bit from mosi
      m_byte = m_byte | (mosi << (7-m_reading));
      // keep reading
      m_reading = (m_reading + 1) & 7;
      if (m_reading == 0) {
        // byte received, process
        m_command();
      }
    }
  }
  m_prev_clk = clk;
}

// ----------------------------------------------------------------------------

void SPIScreen::cmd_idle_SSD1351()
{
  m_step = 0;
  if (!m_dc) {
    // fprintf(stdout,"command: %x\n", m_byte);
    switch (m_byte) {
      case 0x15:
        m_command = std::bind( &SPIScreen::cmd_start_end, this, &m_x_start, &m_x_end, 1);
        break;
      case 0x75:
        m_command = std::bind( &SPIScreen::cmd_start_end, this, &m_y_start, &m_y_end, 1);
        break;
      case 0x5C:
        m_command = std::bind( &SPIScreen::cmd_write_ram, this );
        break;
      case 0xA0:
        m_command = std::bind( &SPIScreen::cmd_mode_SSD1351, this );
        break;
      default:
        break;
    }
  }
}

// ----------------------------------------------------------------------------

void SPIScreen::cmd_mode_SSD1351()
{
  m_color_666_else_565 = (m_byte & 128);
  set_idle();
}

// ----------------------------------------------------------------------------

void SPIScreen::cmd_idle_ST7789_ILI9351()
{
  m_step = 0;
  if (!m_dc) {
    // fprintf(stdout,"command: %x\n", m_byte);
    switch (m_byte) {
      case 0x2A:
        m_command = std::bind( &SPIScreen::cmd_start_end, this, &m_x_start, &m_x_end, 2);
        break;
      case 0x2B:
        m_command = std::bind( &SPIScreen::cmd_start_end, this, &m_y_start, &m_y_end, 2);
        break;
      case 0x2C:
        m_command = std::bind( &SPIScreen::cmd_write_ram, this );
        break;
      case 0x3A:
        m_command = std::bind( &SPIScreen::cmd_mode_ST7789_ILI9351, this );
      default:
        break;
    }
  }
}

// ----------------------------------------------------------------------------

void SPIScreen::cmd_mode_ST7789_ILI9351()
{
  m_color_666_else_565 = ((m_byte>>4) & 7) == 6;
  set_idle();
}

// ----------------------------------------------------------------------------

void SPIScreen::cmd_start_end(int *p_start,int *p_end,int nbytes)
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

void SPIScreen::cmd_write_ram()
{
  if (!m_dc) {
    // exit
    set_idle();
  }
  if (m_step == 0) {
    m_x_cur = m_x_start;
    m_y_cur = m_y_start;
    m_step  = 1;
  }
  if (m_color_666_else_565) {
    // 6-6-6
    m_rgb[(m_step - 1)] = m_byte;
    if (m_step == 3) {
      //fprintf(stdout,"666 x %d, y %d\n",m_x_cur,m_y_cur);
      m_framebuffer.pixel<LibSL::Memory::Array::Wrap>(
                                  m_y_cur,m_x_cur) = m_rgb;
    }
    m_step = m_step + 1;
    if (m_step > 3) {
      m_step = 1;
      ++ m_x_cur;
      if (m_x_cur > m_x_end) {
        m_x_cur = 0;
        ++ m_y_cur;
        if (m_y_cur > m_y_end) {
          m_y_cur = 0;
          m_framebuffer_changed = true;
        }
      }
    }
  } else {
    // 5-6-5
    if (m_step == 1) {
      m_rgb[1] = (m_byte & 7);
      m_rgb[2] = (m_byte >> 3);
    } else {
      m_rgb[1] = (m_rgb[1] << 3) | (m_byte >> 5);
      m_rgb[0] = (m_byte & 31);
    }
    if (m_step == 2) {
      if (1) {
        // bgr
        std::swap(m_rgb[0],m_rgb[2]);
      }
      //fprintf(stdout,"565 x %d, y %d rgb:%x,%x,%x\n",
      //        m_x_cur,m_y_cur,(int)m_rgb[0],(int)m_rgb[1],(int)m_rgb[2]);
      m_rgb[0] <<= 3;      m_rgb[1] <<= 2;      m_rgb[2] <<= 3;
      m_framebuffer.pixel<LibSL::Memory::Array::Wrap>(
                                  m_y_cur,m_x_cur) = m_rgb;
    }
    m_step = m_step + 1;
    if (m_step > 2) {
      m_step = 1;
      ++ m_x_cur;
      if (m_x_cur > m_x_end) {
        m_x_cur = 0;
        ++ m_y_cur;
        if (m_y_cur > m_y_end) {
          m_y_cur = 0;
          m_framebuffer_changed = true;
        }
      }
    }
  }
}

// ----------------------------------------------------------------------------

bool SPIScreen::framebufferChanged()
{
  bool changed = m_framebuffer_changed;
  m_framebuffer_changed = false;
  return changed;
}

// ----------------------------------------------------------------------------
