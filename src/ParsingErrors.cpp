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

#include "ParsingErrors.h"
#include "ParsingContext.h"
#include "Utils.h"
#include "Config.h"

// -------------------------------------------------

#include <string>
#include <iostream>
#include <fstream>
#include <regex>
#include <queue>
#include <cstdio>

#include <LibSL/LibSL.h>

using namespace Silice;
using namespace Silice::Utils;

// -------------------------------------------------

void ReportError::printReport(std::pair<std::string, int> where, std::string msg) const
{
  std::cerr << Console::bold << Console::white << "----------<<<<< error >>>>>----------" << nxl << nxl;
  if (where.second > -1) {
    std::cerr
      << "=> file: " << where.first << nxl
      << "=> line: " << where.second+1 << nxl
      << Console::normal << nxl;
  }
  std::vector<std::string> items;
  split(msg, '#', items);
  if (items.size() == 5) {
    std::cerr << nxl;
    std::cerr << Console::white << Console::bold;
    std::cerr << items[1] << nxl;
    int nl = numLinesIn(items[1]);
    if (nl == 0) {
      ForIndex(i, std::stoi(items[3])) {
        std::cerr << ' ';
      }
      std::cerr << Console::yellow << Console::bold;
      ForRange(i, std::stoi(items[3]), std::stoi(items[4])) {
        std::cerr << '^';
      }
    } else {
      std::cerr << nxl;
      std::cerr << Console::yellow << Console::bold;
      std::cerr << "--->";
    }
    std::cerr << Console::red;
    std::cerr << " " << items[0] << nxl;
    std::cerr << Console::gray;
    std::cerr << nxl;
  } else {
    std::cerr << Console::red << Console::bold;
    std::cerr << msg << nxl;
    std::cerr << Console::normal;
    std::cerr << nxl;
  }
}

// -------------------------------------------------

#if !defined(_WIN32) && !defined(_WIN64) && !defined(fopen_s)
#define fopen_s(f,n,m) ((*f) = fopen(n,m))
#endif

// -------------------------------------------------

std::string ReportError::prepareMessage(antlr4::TokenStream* tk_stream, antlr4::Token* offender, antlr4::misc::Interval interval) const
{
  std::string msg = "";
  if (tk_stream != nullptr && (offender != nullptr || !(interval == antlr4::misc::Interval::INVALID))) {
    msg = "#";
    std::string file;
    std::string codeline;
    int first=0, last=0;
    getSourceInfo(tk_stream, offender, interval, file, codeline, first, last);
    msg += codeline;
    msg += "#";
    msg += tk_stream->getText(offender, offender);
    msg += "#";
    msg += std::to_string(first);
    msg += "#";
    msg += std::to_string(last);
  }
  return msg;
}

// -------------------------------------------------

ReportError::ReportError(ParsingContext *pctx,
  int line, antlr4::TokenStream* tk_stream,
  antlr4::Token *offender, antlr4::misc::Interval interval, std::string msg)
{
  msg += prepareMessage(tk_stream, offender, interval);
  if (line == -1) {
    line = lineFromInterval(tk_stream, interval)-1;
  }
  if (pctx == nullptr) {
    pctx = ParsingContext::activeContext();
  }
  printReport(pctx->lpp->lineAfterToFileAndLineBefore(pctx, (int)line), msg);
}

// -------------------------------------------------

void LexerErrorListener::syntaxError(
  antlr4::Recognizer* recognizer,
  antlr4::Token* tk,
  size_t line,
  size_t charPositionInLine,
  const std::string& msg, std::exception_ptr e)
{
  ReportError err(nullptr, (int)line-1, nullptr, nullptr, antlr4::misc::Interval(), msg);
  throw Fatal("[lexical error]");
}

// -------------------------------------------------

void ParserErrorListener::syntaxError(
  antlr4::Recognizer* recognizer,
  antlr4::Token*      tk,
  size_t              line,
  size_t              charPositionInLine,
  const std::string&  msg,
  std::exception_ptr  e)
{
  ReportError err(nullptr, (int)line-1, dynamic_cast<antlr4::TokenStream*>(recognizer->getInputStream()), tk, antlr4::misc::Interval::INVALID, msg);
   throw Fatal("[syntax error]");
}

// -------------------------------------------------

void ParserErrorHandler::reportNoViableAlternative(antlr4::Parser* parser, antlr4::NoViableAltException const& ex)
{
  std::string msg = "surprised to find this here";
  parser->notifyErrorListeners(ex.getOffendingToken(), msg, std::make_exception_ptr(ex));
}

// -------------------------------------------------

void ParserErrorHandler::reportInputMismatch(antlr4::Parser* parser, antlr4::InputMismatchException const& ex)
{
  std::string msg = "expecting something else";
  parser->notifyErrorListeners(ex.getOffendingToken(), msg, std::make_exception_ptr(ex));
}

// -------------------------------------------------

void ParserErrorHandler::reportFailedPredicate(antlr4::Parser* parser, antlr4::FailedPredicateException const& ex)
{
  std::string msg = "surprised to find this here";
  parser->notifyErrorListeners(ex.getOffendingToken(), msg, std::make_exception_ptr(ex));
}

// -------------------------------------------------

void ParserErrorHandler::reportUnwantedToken(antlr4::Parser* parser)
{
  std::string msg = "this should not be here";
  antlr4::Token* tk = parser->getCurrentToken();
  parser->notifyErrorListeners(tk, msg, nullptr);
}

// -------------------------------------------------

void ParserErrorHandler::reportMissingToken(antlr4::Parser* parser)
{
  std::string msg = "missing symbol after this";
  antlr4::Token* tk = parser->getCurrentToken();
  antlr4::TokenStream* tk_stream = dynamic_cast<antlr4::TokenStream*>(parser->getInputStream());
  if (tk_stream != nullptr) {
    int index = (int)tk->getTokenIndex();
    if (index > 0) {
      tk = tk_stream->get(index - 1);
    }
  }
  parser->notifyErrorListeners(tk, msg, nullptr);
}

// -------------------------------------------------
