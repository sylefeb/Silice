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

#include "ParsingContext.h"
#include "Utils.h"
#include "Algorithm.h"

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

ParsingContext::ParsingContext(
  std::string              fresult_,
  AutoPtr<LuaPreProcessor> lpp_,
  std::string              preprocessed,
  std::string              framework_verilog_,
  const std::vector<std::string>& defines_)
{
  fresult           = fresult_;
  framework_verilog = framework_verilog_;
  defines           = defines_;
  lpp               = lpp_;
  // initiate parsing
  lexerErrorListener  = AutoPtr<LexerErrorListener>(new LexerErrorListener(*lpp));
  parserErrorListener = AutoPtr<ParserErrorListener>(new ParserErrorListener(*lpp));
  input               = AutoPtr<antlr4::ANTLRFileStream>(new antlr4::ANTLRFileStream(preprocessed));
  lexer               = AutoPtr<siliceLexer>(new siliceLexer(input.raw()));
  tokens              = AutoPtr<antlr4::CommonTokenStream>(new antlr4::CommonTokenStream(lexer.raw()));
  parser              = AutoPtr<siliceParser>(new siliceParser(tokens.raw()));
  err_handler         = std::make_shared<ParserErrorHandler>();
  parser->setErrorHandler(err_handler);
  lexer ->removeErrorListeners();
  lexer ->addErrorListener(lexerErrorListener.raw());
  parser->removeErrorListeners();
  parser->addErrorListener(parserErrorListener.raw());
}

// -------------------------------------------------

void ParsingContext::bind()
{
  Utils::setTokenStream(dynamic_cast<antlr4::TokenStream*>(parser->getInputStream()));
  Utils::setLuaPreProcessor(lpp.raw());
  Algorithm::setLuaPreProcessor(lpp.raw());
}

// -------------------------------------------------

void ParsingContext::unbind()
{
  Utils::setTokenStream(nullptr);
  Utils::setLuaPreProcessor(nullptr);
  Algorithm::setLuaPreProcessor(nullptr);
}

// -------------------------------------------------

ParsingContext::~ParsingContext()
{

}

// -------------------------------------------------
