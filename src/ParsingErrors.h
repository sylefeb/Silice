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

#include "siliceLexer.h"
#include "siliceParser.h"

#include "LuaPreProcessor.h"

#include <LibSL/LibSL.h>

namespace Silice {

  // -------------------------------------------------

  /// \brief class for error reporting from ANTL status
  class ReportError
  {
  private:

    void        printReport(std::pair<std::string, int> where, std::string msg) const;
    int         lineFromInterval(antlr4::TokenStream *tk_stream, antlr4::misc::Interval interval) const;
    std::string extractCodeAroundToken(std::string file, antlr4::Token *tk, antlr4::TokenStream *tk_stream, int &_offset) const;
    std::string prepareMessage(antlr4::TokenStream* tk_stream, antlr4::Token *offender, antlr4::misc::Interval tk_interval) const;

  public:

    ReportError(ParsingContext *pctx, int line, antlr4::TokenStream* tk_stream,
      antlr4::Token *offender, antlr4::misc::Interval tk_interval, std::string msg);

  };

  // -------------------------------------------------

  /// \brief class for ANTLR lexer error reporting
  class LexerErrorListener : public antlr4::BaseErrorListener
  {
  private:
    const LuaPreProcessor &m_PreProcessor;
  public:
    LexerErrorListener(const LuaPreProcessor &pp) : m_PreProcessor(pp) {}
    virtual void syntaxError(
      antlr4::Recognizer* recognizer,
      antlr4::Token* tk,
      size_t line,
      size_t charPositionInLine,
      const std::string& msg, std::exception_ptr e) override;
  };

  // -------------------------------------------------

  /// \brief class for ANTLR parsing error reporting
  class ParserErrorListener : public antlr4::BaseErrorListener
  {
  private:
    const LuaPreProcessor &m_PreProcessor;
  public:
    ParserErrorListener(const LuaPreProcessor &pp) : m_PreProcessor(pp) {}
    virtual void syntaxError(
      antlr4::Recognizer* recognizer,
      antlr4::Token*      tk,
      size_t              line,
      size_t              charPositionInLine,
      const std::string&  msg,
      std::exception_ptr  e) override;
  };

  // -------------------------------------------------

  /// \brief class for ANTLR error handling strategy
  class ParserErrorHandler : public antlr4::DefaultErrorStrategy
  {
  protected:
    void reportNoViableAlternative(antlr4::Parser *parser, antlr4::NoViableAltException const &ex) override;
    void reportInputMismatch(antlr4::Parser *parser, antlr4::InputMismatchException const &ex) override;
    void reportFailedPredicate(antlr4::Parser *parser, antlr4::FailedPredicateException const &ex) override;
    void reportUnwantedToken(antlr4::Parser *parser) override;
    void reportMissingToken(antlr4::Parser *parser) override;
  };


  // -------------------------------------------------

};
