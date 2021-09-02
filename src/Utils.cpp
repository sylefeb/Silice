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

using namespace LibSL; 
using namespace Silice;

// -------------------------------------------------

static antlr4::TokenStream *s_TokenStream = nullptr;
static LuaPreProcessor     *s_LuaPreProcessor = nullptr;

// -------------------------------------------------

void Utils::reportError(antlr4::Token *what, int line, const char *msg, ...)
{
  const int messageBufferSize = 4096;
  char message[messageBufferSize];

  va_list args;
  va_start(args, msg);
  vsprintf_s(message, messageBufferSize, msg, args);
  va_end(args);

  throw LanguageError(line, what, antlr4::misc::Interval::INVALID, "%s", message);
}

// -------------------------------------------------

void Utils::reportError(antlr4::misc::Interval interval, int line, const char *msg, ...)
{
  const int messageBufferSize = 4096;
  char message[messageBufferSize];

  va_list args;
  va_start(args, msg);
  vsprintf_s(message, messageBufferSize, msg, args);
  va_end(args);

  throw LanguageError(line, nullptr, interval, "%s", message);
}

// -------------------------------------------------

void Utils::warn(e_WarningType type, antlr4::misc::Interval interval, int line, const char *msg, ...)
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
  if (line > -1) {
  } else if (s_TokenStream != nullptr && !(interval == antlr4::misc::Interval::INVALID)) {
    antlr4::Token *tk = s_TokenStream->get(interval.a);
    line = (int)tk->getLine();
  }
  if (s_LuaPreProcessor != nullptr) {
    auto fl = s_LuaPreProcessor->lineAfterToFileAndLineBefore(line);
    std::cerr << "(" << Console::white << fl.first << Console::gray << ", line " << sprint("%4d", fl.second) << ") ";
  } else {
    std::cerr << "(" << line << ") ";
  }
  std::cerr << "\n             " << message;
  std::cerr << "\n";
}

// -------------------------------------------------

antlr4::Token *Utils::getToken(antlr4::misc::Interval interval, bool last_else_first)
{
  if (s_TokenStream != nullptr && !(interval == antlr4::misc::Interval::INVALID)) {
    antlr4::Token *tk = s_TokenStream->get(last_else_first ? interval.b : interval.a);
    return tk;
  } else {
    return nullptr;
  }
}

// -------------------------------------------------

std::pair<std::string, int> Utils::getTokenSourceFileAndLine(antlr4::Token *tk)
{
  int line = (int)tk->getLine();
  if (s_LuaPreProcessor != nullptr) {
    auto fl = s_LuaPreProcessor->lineAfterToFileAndLineBefore(line);
    return fl;
  } else {
    return std::make_pair("", line);
  }
}

// -------------------------------------------------

void Utils::setTokenStream(antlr4::TokenStream *tks)
{
  s_TokenStream = tks;
}

// -------------------------------------------------

void Utils::setLuaPreProcessor(LuaPreProcessor *lpp)
{
  s_LuaPreProcessor = lpp;
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

std::string Utils::extractCodeBetweenTokens(std::string file, int stk, int etk)
{
  if (file.empty()) {
    file = s_TokenStream->getTokenSource()->getInputStream()->getSourceName();
  }
  int sidx = (int)s_TokenStream->get(stk)->getStartIndex();
  int eidx = (int)s_TokenStream->get(etk)->getStopIndex();
  FILE *f = NULL;
  fopen_s(&f, file.c_str(), "rb");
  if (f) {
    char buffer[256];
    fseek(f, sidx, SEEK_SET);
    int read = (int)fread(buffer, 1, min(255, eidx - sidx + 1), f);
    buffer[read] = '\0';
    fclose(f);
    return std::string(buffer);
  }
  return s_TokenStream->getText(s_TokenStream->get(stk), s_TokenStream->get(etk));
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
