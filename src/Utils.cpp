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
// -------------------------------------------------

#include "Utils.h"
#include <LibSL.h>

#include "LuaPreProcessor.h"
#include "ParsingContext.h"

#include <filesystem>

using namespace LibSL;
using namespace Silice;

// -------------------------------------------------

static Utils::t_source_loc nowhere;

// -------------------------------------------------

void Utils::reportError(const t_source_loc& srcloc, const char *msg, ...)
{
  const int messageBufferSize = 4096;
  char message[messageBufferSize];

  va_list args;
  va_start(args, msg);
  vsprintf_s(message, messageBufferSize, msg, args);
  va_end(args);

  ParsingContext *pctx = nullptr;
  if (srcloc.root) {
    pctx = ParsingContext::rootContext(srcloc.root);
  } else {
    pctx = ParsingContext::activeContext();
  }
  throw ReportError(pctx, -1, pctx->parser->getTokenStream(), nullptr, srcloc.interval, message);
}

// -------------------------------------------------

void Utils::warn(e_WarningType type, const t_source_loc& srcloc, const char *msg, ...)
{
  const int messageBufferSize = 4096;
  char message[messageBufferSize];

  va_list args;
  va_start(args, msg);
  vsprintf_s(message, messageBufferSize, msg, args);
  va_end(args);

  switch (type) {
  case Standard:    std::cerr << Console::yellow << "[warning]    " << Console::gray; break;
  case Deprecation: std::cerr << Console::cyan << "[deprecated] " << Console::gray; break;
  }
  antlr4::TokenStream *tks = nullptr;
  ParsingContext *pctx = nullptr;
  if (srcloc.root) {
    pctx = ParsingContext::rootContext(Utils::root(srcloc.root));
  }
  if (pctx) {
    tks = pctx->parser->getTokenStream();
  }
  int line = -1;
  if (tks != nullptr && !(srcloc.interval == antlr4::misc::Interval::INVALID)) {
    antlr4::Token *tk = tks->get(srcloc.interval.a);
    line = (int)tk->getLine();
  }
  if (pctx != nullptr) {
    auto fl = pctx->lpp->lineAfterToFileAndLineBefore(pctx,line);
    std::cerr << "(" << Console::white << fl.first << Console::gray << ", line " << sprint("%4d", fl.second) << ") ";
  } else {
    std::cerr << "(" << line << ") ";
  }
  std::cerr << "\n             " << message;
  std::cerr << "\n";
}

// -------------------------------------------------

antlr4::Token *Utils::getToken(antlr4::tree::ParseTree *node, antlr4::misc::Interval interval, bool last_else_first)
{
  antlr4::TokenStream *tks = nullptr;
  ParsingContext *pctx = nullptr;
  if (node) {
    pctx = ParsingContext::rootContext(Utils::root(node));
  }
  if (pctx) {
    tks = pctx->parser->getTokenStream();
  }
  if (tks != nullptr && !(interval == antlr4::misc::Interval::INVALID)) {
    antlr4::Token *tk = tks->get(last_else_first ? interval.b : interval.a);
    return tk;
  } else {
    return nullptr;
  }
}

// -------------------------------------------------

std::pair<std::string, int> Utils::getTokenSourceFileAndLine(antlr4::tree::ParseTree *node, antlr4::Token *tk)
{
  ParsingContext *pctx = nullptr;
  if (node) {
    pctx = ParsingContext::rootContext(Utils::root(node));
  } else {
    pctx = ParsingContext::activeContext();
  }
  int line = (int)tk->getLine();
  if (pctx != nullptr) {
    auto fl = pctx->lpp->lineAfterToFileAndLineBefore(pctx,line-1);
    return fl;
  } else {
    return std::make_pair("", line);
  }
}

// -------------------------------------------------

v2i Utils::instructionLines(antlr4::tree::ParseTree* instr)
{
  auto tk_start = getToken(instr, instr->getSourceInterval(), false);
  auto tk_end   = getToken(instr, instr->getSourceInterval(), true);
  if (tk_start && tk_end) {
    std::pair<std::string, int> fl_start = getTokenSourceFileAndLine(instr, tk_start);
    std::pair<std::string, int> fl_end   = getTokenSourceFileAndLine(instr, tk_end);
    return v2i(fl_start.second, fl_end.second);
  }
  return v2i(-1,-1);
}

// -------------------------------------------------

int Utils::justHigherPow2(int n)
{
  int  p2 = 0;
  bool isp2 = true;
  while (n > 0) {
    if (n > 1 && (n & 1)) {
      isp2 = false;
    }
    ++p2;
    n = n >> 1;
  }
  return isp2 ? p2 - 1 : p2;
}

// -------------------------------------------------

int Utils::lineFromInterval(antlr4::TokenStream *tk_stream, antlr4::misc::Interval interval)
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

std::string Utils::extractCodeAroundToken(std::string file, antlr4::Token* tk, antlr4::TokenStream* tk_stream, int& _offset)
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

std::string Utils::extractCodeBetweenTokens(std::string file, antlr4::TokenStream* tk_stream, int stk, int etk)
{
  if (file.empty()) {
    file = tk_stream->getTokenSource()->getInputStream()->getSourceName();
  }
  int sidx = (int)tk_stream->get(stk)->getStartIndex();
  int eidx = (int)tk_stream->get(etk)->getStopIndex();
  FILE *f = NULL;
  fopen_s(&f, file.c_str(), "rb");
  if (f) {
    Array<char> buffer;
    buffer.allocate(eidx - sidx + 2);
    fseek(f, sidx, SEEK_SET);
    int read = (int)fread(buffer.raw(), 1, eidx - sidx + 1, f);
    buffer[read] = '\0';
    fclose(f);
    return std::string(buffer.raw());
  }
  return tk_stream->getText(tk_stream->get(stk), tk_stream->get(etk));
}

// -------------------------------------------------

void Utils::getSourceInfo(
  antlr4::TokenStream* tk_stream, antlr4::Token* offender, antlr4::misc::Interval interval, 
  std::string& _file, std::string& _code, int& _first, int& _last)
{
  sl_assert(tk_stream != nullptr);
  sl_assert(offender != nullptr || !(interval == antlr4::misc::Interval::INVALID));
  _file = tk_stream->getTokenSource()->getInputStream()->getSourceName();
  int offset = 0;
  if (offender != nullptr) {
    tk_stream->getText(offender, offender); // this seems required to refresh the stream? TODO FIXME investigate
    _code = extractCodeAroundToken(_file, offender, tk_stream, offset);
  } else if (!(interval == antlr4::misc::Interval::INVALID)) {
    if (interval.a > interval.b) {
      std::swap(interval.a, interval.b);
    }
    _code = extractCodeBetweenTokens(_file, tk_stream, (int)interval.a, (int)interval.b);
    offset = (int)tk_stream->get(interval.a)->getStartIndex();
  }
  if (offender != nullptr) {
    _first = offender->getStartIndex() - offset;
    _last  = offender->getStopIndex() - offset;
  } else if (!(interval == antlr4::misc::Interval::INVALID)) {
    _first = tk_stream->get(interval.a)->getStartIndex() - offset;
    _last  = tk_stream->get(interval.b)->getStopIndex() - offset;
  }
}

// -------------------------------------------------

std::string Utils::fileToString(const char* file)
{
  std::ifstream infile(file);
  if (!infile) {
    throw LibSL::Errors::Fatal("[Utils::fileToString] - file '%s' not found", file);
  }
  std::ostringstream strstream;
  while (infile) { // TODO: improve efficienty
    std::ifstream::int_type c = infile.get();
    if (c != (-1)) // EOF
      strstream << char(c);
    else
      break;
  }
  return strstream.str();
}

// -------------------------------------------------

std::string Utils::tempFileName()
{
  static int cnt = 0;
  static std::string key;
  if (key.empty()) {
    srand((unsigned int)time(NULL));
    for (int i = 0; i < 16; ++i) {
      key += (char)((int)'a' + (rand() % 26));
    }
  }
  std::string tmp = std::filesystem::temp_directory_path().string()
    + "/" + key + std::to_string(cnt++);
  return tmp;
}

// -------------------------------------------------

void Utils::split(const std::string& s, char delim, std::vector<std::string>& elems)
{
  std::stringstream ss(s);
  std::string item;
  while (getline(ss, item, delim)) {
    elems.push_back(item);
  }
}

// -------------------------------------------------

int Utils::numLinesIn(std::string l)
{
  return (int)std::count(l.begin(), l.end(), '\n');
}

// -------------------------------------------------

antlr4::tree::ParseTree *Utils::root(antlr4::tree::ParseTree *node)
{
  while (node->parent != nullptr) {
    node = node->parent;
  }
  return node;
}

// -------------------------------------------------

Utils::t_source_loc Utils::sourceloc(antlr4::tree::ParseTree *node)
{
  t_source_loc sl;
  sl.root = Utils::root(node);
  sl.interval = node->getSourceInterval();
  return sl;
}

// -------------------------------------------------

Utils::t_source_loc Utils::sourceloc(antlr4::tree::ParseTree *root, antlr4::misc::Interval interval)
{
  t_source_loc sl;
  sl.root = root;
  sl.interval = interval;
  return sl;
}

// -------------------------------------------------
