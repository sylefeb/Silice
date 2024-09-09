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

#include "PWMAudio.h"
#include <iostream>
#include <fstream>

#define SAMPLE_FREQ (48828/4) // because its a nice multiple of 25MHz ...

/// TODO: lots of assumptions here, generalize!

// ----------------------------------------------------------------------------

PWMAudio::PWMAudio(double clock_freq_MHz)
{
  double sound_freq_Hz   = SAMPLE_FREQ;
  m_sound_sample_period  = clock_freq_MHz * 1000000.0 / sound_freq_Hz;
  m_sound_sample_counter = m_sound_sample_period;
  m_save_wave_period     = clock_freq_MHz * 1000000.0 / 1.0; // every second
  m_save_wave_counter    = m_save_wave_period;
  std::cerr << "PWMAudio: clock reported at " << clock_freq_MHz << '\n';
  std::cerr << "PWMAudio: sound sample period is " << m_sound_sample_period << " cycles\n";
  m_num_high = 0;
}

// ----------------------------------------------------------------------------

void PWMAudio::eval(
            vluint8_t  clk,
            vluint8_t  pwm_audio)
{
  if (clk && !m_prev_clk) {
    if (pwm_audio) ++ m_num_high;
    -- m_sound_sample_counter;
    if (m_sound_sample_counter == 0) {
      m_sound_sample_counter = m_sound_sample_period;
      // next sample
      int sample = (65535 * m_num_high) / m_sound_sample_period - 32767;
      int prev_sample = m_wave.empty() ? sample : m_wave.back();
      m_wave.push_back((sample*8 + prev_sample*8)/16);
      // std::cerr << "PWMAudio: sample: " << sample << '\n';
      m_num_high = 0;
    }
    -- m_save_wave_counter;
    if (m_save_wave_counter == 0) {
      m_save_wave_counter = m_save_wave_period;
      writeWave("out.wav",m_wave,SAMPLE_FREQ);
    }
  }
  m_prev_clk = clk;
}

// ----------------------------------------------------------------------------

void PWMAudio::writeWave(std::string fname, const std::vector<int16_t>& data, int sampleRate)
{
  std::ofstream file(fname, std::ios::binary);
  if (!file) {
    std::cerr << "PWMAudio: cannot save to " << fname << std::endl;
    return;
  }
  // header
  file.write("RIFF", 4);
  uint32_t chunkSize = 36 + data.size() * sizeof(short);
  file.write((const char*)&chunkSize, sizeof(chunkSize));
  file.write("WAVE", 4);
  // format
  file.write("fmt ", 4);
  uint32_t subchunk1Size = 16; // PCM header size
  file.write((const char*)&subchunk1Size, sizeof(subchunk1Size));
  uint16_t audioFormat = 1; // PCM
  file.write((const char*)&audioFormat, sizeof(audioFormat));
  uint16_t numChannels = 1;
  file.write((const char*)&numChannels, sizeof(numChannels));
  file.write((const char*)&sampleRate, sizeof(sampleRate));
  uint32_t byteRate = sampleRate * numChannels * sizeof(short);
  file.write((const char*)&byteRate, sizeof(byteRate));
  uint16_t blockAlign = numChannels * sizeof(short);
  file.write((const char*)&blockAlign, sizeof(blockAlign));
  uint16_t bitsPerSample = 16;
  file.write((const char*)&bitsPerSample, sizeof(bitsPerSample));
  // data
  file.write("data", 4);
  uint32_t dataChunkSize = data.size() * sizeof(short);
  file.write((const char*)&dataChunkSize, sizeof(dataChunkSize));
  file.write((const char*)data.data(), dataChunkSize);

  file.close();
}

// ----------------------------------------------------------------------------
