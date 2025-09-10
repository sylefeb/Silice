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
// Sylvain Lefebvre 2024-09-08

#pragma once

#include "verilated.h"

#include <vector>

/// \brief Implements 1-bit PWM audio
class PWMAudio
{
private:

  double    m_clock_freq_MHz;
  vluint8_t m_prev_clk;
  int       m_sound_sample_period;
  int       m_sound_sample_counter;
  int       m_save_wave_period;
  int       m_save_wave_counter;
  int       m_num_high;

  std::vector<int16_t> m_wave;

  void writeWave(std::string fname, const std::vector<int16_t>& data, int sampleRate);

public:

  PWMAudio(double clock_freq_MHz);
  ~PWMAudio();

  void eval(vluint8_t  clk,
            vluint8_t  pwm_audio);

};
