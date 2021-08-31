/*

    Silice FPGA language and compiler
    Copyright 2019, (C) Sylvain Lefebvre and contributors

    List contributors with: git shortlog -n -s -- <filename>

    GPLv3 license, see LICENSE_GPLv3 in Silice repo root

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation, either version 3 of the License, or (at your option)
any later version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program.  If not, see <https://www.gnu.org/licenses/>.

(header_2_G)
*/
#pragma once
// -------------------------------------------------

#include "siliceLexer.h"
#include "siliceParser.h"

namespace Silice
{

  namespace Utils
  {

    // -------------------------------------------------

    /// \brief return next higher power of two covering n
    int  justHigherPow2(int n);
    /// \brief report an error using token or line number
    void reportError(antlr4::Token *what, int line, const char *msg, ...);
    /// \brief report an error using source interval or line number
    void reportError(antlr4::misc::Interval interval, int line, const char *msg, ...);

    // -------------------------------------------------

    class LanguageError
    {
    public:
      enum { e_MessageBufferSize = 4096 };
    private:
      int            m_Line = -1;
      antlr4::Token *m_Token = nullptr;
      antlr4::misc::Interval  m_Interval;
      char           m_Message[e_MessageBufferSize];
      LanguageError() { m_Message[0] = '\0'; }
    public:
      LanguageError(int line, antlr4::Token *tk, antlr4::misc::Interval interval, const char *msg, ...)
#if !defined(_WIN32) && !defined(_WIN64)
        __attribute__((format(printf, 5, 6)))
#endif
      {
        m_Line = line;
        m_Token = tk;
        m_Interval = interval;
        va_list args;
        va_start(args, msg);
        vsprintf_s(m_Message, e_MessageBufferSize, msg, args);
        va_end(args);
      }
      int line() const { return m_Line; }
      const char *message()  const { return (m_Message); }
      antlr4::Token *token() { return m_Token; }
      antlr4::misc::Interval  interval() { return m_Interval; }
    };

  };

};

// -------------------------------------------------
