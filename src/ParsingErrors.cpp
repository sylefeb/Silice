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

#if !defined(_WIN32)  && !defined(_WIN64)
#define fopen_s(f,n,m) ((*f) = fopen(n,m))
#endif

// -------------------------------------------------

std::string ReportError::extractCodeAroundToken(std::string file, antlr4::Token* tk, antlr4::TokenStream* tk_stream, int& _offset) const
{
  antlr4::Token* first_tk = tk;
  int index = (int)first_tk->getTokenIndex();
  int tkline = (int)first_tk->getLine();
  while (index > 0) {
    first_tk = tk_stream->get(--index);
    if (first_tk->getLine() < tkline) {
      first_tk = tk_stream->get(index + 1);
      break;
    }
  }
  antlr4::Token* last_tk = tk;
  index = (int)last_tk->getTokenIndex();
  tkline = (int)last_tk->getLine();
  while (index < (int)tk_stream->size() - 2) {
    last_tk = tk_stream->get(++index);
    if (last_tk->getLine() > tkline) {
      last_tk = tk_stream->get(index - 1);
      break;
    }
  }
  _offset = (int)first_tk->getStartIndex();
  // now extract from file
  return extractCodeBetweenTokens(file, tk_stream, (int)first_tk->getTokenIndex(), (int)last_tk->getTokenIndex());
}

// -------------------------------------------------

std::string ReportError::prepareMessage(antlr4::TokenStream* tk_stream, antlr4::Token* offender, antlr4::misc::Interval interval) const
{
  std::string msg = "";
  if (tk_stream != nullptr && (offender != nullptr || !(interval == antlr4::misc::Interval::INVALID))) {
    msg = "#";
    std::string file = tk_stream->getTokenSource()->getInputStream()->getSourceName();
    int offset = 0;
    std::string codeline;
    if (offender != nullptr) {
      tk_stream->getText(offender, offender); // this seems required to refresh the steam? TODO FIXME investigate
      codeline = extractCodeAroundToken(file, offender, tk_stream, offset);
    } else if (!(interval == antlr4::misc::Interval::INVALID)) {
      if (interval.a > interval.b) {
        std::swap(interval.a, interval.b);
      }
      codeline = extractCodeBetweenTokens(file, tk_stream, (int)interval.a, (int)interval.b);
      offset = (int)tk_stream->get(interval.a)->getStartIndex();
    }
    msg += codeline;
    msg += "#";
    msg += tk_stream->getText(offender, offender);
    msg += "#";
    if (offender != nullptr) {
      msg += std::to_string(offender->getStartIndex() - offset);
      msg += "#";
      msg += std::to_string(offender->getStopIndex() - offset);
    } else if (!(interval == antlr4::misc::Interval::INVALID)) {
      msg += std::to_string(tk_stream->get(interval.a)->getStartIndex() - offset);
      msg += "#";
      msg += std::to_string(tk_stream->get(interval.b)->getStopIndex() - offset);
    }
  }
  return msg;
}

// -------------------------------------------------

int ReportError::lineFromInterval(antlr4::TokenStream *tk_stream, antlr4::misc::Interval interval) const
{
  if (tk_stream != nullptr && !(interval == antlr4::misc::Interval::INVALID)) {
    // attempt to recover source line from interval only
    antlr4::Token *tk = tk_stream->get(interval.a);
    return (int)tk->getLine();
  } else {
    return -1;
  }
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
