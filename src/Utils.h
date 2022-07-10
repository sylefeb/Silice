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
  class LuaPreProcessor;
  class ParsingContext;

  namespace Utils
  {

    // -------------------------------------------------

    /// \brief source location for error reporting
    typedef struct {
      antlr4::misc::Interval    interval = antlr4::misc::Interval::INVALID; // block source interval
      antlr4::tree::ParseTree  *root = nullptr; // root of the parse tree where the var is declared
    } t_source_loc;

    static t_source_loc nowhere;

    // -------------------------------------------------

    /// \brief return next higher power of two covering n
    int  justHigherPow2(int n);
    /// \brief report an error using source tree node
    void reportError(const t_source_loc& srcloc, const char *msg, ...);
    /// \brief types of warnings
    enum e_WarningType { Standard, Deprecation };
    /// \brief issues a warning
    void warn(e_WarningType type, const t_source_loc& srcloc, const char *msg, ...);
    /// \brief get a token from a source interval (helper)
    antlr4::Token *getToken(antlr4::tree::ParseTree *node, antlr4::misc::Interval interval, bool last_else_first = false);
    /// \brief returns the source file and line for the given token (helper)
    std::pair<std::string, int> getTokenSourceFileAndLine(antlr4::tree::ParseTree *node, antlr4::Token *tk);
    /// \brief extracts a piece of source code in between given tokens
    std::string extractCodeBetweenTokens(std::string file, antlr4::TokenStream* tk_stream, int stk, int etk);
    /// \brief loads the content of file into a string
    std::string fileToString(const char* file);
    /// \brief returns a temporary filename (within temporary directory)
    std::string tempFileName();
    /// \brief splits a string with a delimiter
    void split(const std::string& s, char delim, std::vector<std::string>& elems);
    /// \brief returns the number of lines in string l
    int  numLinesIn(std::string l);
    /// \brief go up to the root
    antlr4::tree::ParseTree *root(antlr4::tree::ParseTree *node);
    /// \brief build a source localizer
    t_source_loc sourceloc(antlr4::tree::ParseTree *node);
    t_source_loc sourceloc(antlr4::tree::ParseTree *root, antlr4::misc::Interval interval);

    // -------------------------------------------------

  };

};

// -------------------------------------------------
