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

  class RISCVSynthesizer
  {
  private:

    /// \brief Token stream for extracting C/C++ source code
    static antlr4::TokenStream *s_TokenStream;

    std::string cblockToString(siliceParser::CblockContext *cblock) const;

    std::string extractCodeBetweenTokens(std::string file, int stk, int etk) const;

    std::string generateCHeader(siliceParser::RiscvContext *riscv) const;

  public:

    RISCVSynthesizer(siliceParser::RiscvContext *riscv);

    /// \brief set the token stream
    static void setTokenStream(antlr4::TokenStream *tks)
    {
      s_TokenStream = tks;
    }

  };

};

// -------------------------------------------------
