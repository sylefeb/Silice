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

std::vector<ParsingContext*>                        ParsingContext::s_ActiveContext;
std::map<antlr4::tree::ParseTree*, ParsingContext*> ParsingContext::s_Root2Context;

typedef struct {
  antlr4::TokenStream *stream;
  LuaPreProcessor     *lpp;
} context_rec;

std::vector<context_rec> s_context_stack;

// -------------------------------------------------

ParsingContext::ParsingContext(
  std::string              fresult_,
  AutoPtr<LuaPreProcessor> lpp_,
  std::string              framework_verilog_,
  const std::vector<std::string>& defines_)
{
  fresult           = fresult_;
  framework_verilog = framework_verilog_;
  defines           = defines_;
  lpp               = lpp_;
}

// -------------------------------------------------

antlr4::tree::ParseTree* ParsingContext::parse(std::string preprocessed)
{
  // initiate parsing
  lexerErrorListener = AutoPtr<LexerErrorListener>(new LexerErrorListener(*lpp));
  parserErrorListener = AutoPtr<ParserErrorListener>(new ParserErrorListener(*lpp));
  input = AutoPtr<antlr4::ANTLRFileStream>(new antlr4::ANTLRFileStream(preprocessed));
  lexer = AutoPtr<siliceLexer>(new siliceLexer(input.raw()));
  tokens = AutoPtr<antlr4::CommonTokenStream>(new antlr4::CommonTokenStream(lexer.raw()));
  parser = AutoPtr<siliceParser>(new siliceParser(tokens.raw()));
  err_handler = std::make_shared<ParserErrorHandler>();
  parser->setErrorHandler(err_handler);
  lexer->removeErrorListeners();
  lexer->addErrorListener(lexerErrorListener.raw());
  parser->removeErrorListeners();
  parser->addErrorListener(parserErrorListener.raw());
  // update stream binding
  Utils::setTokenStream(dynamic_cast<antlr4::TokenStream*>(parser->getInputStream()));
  s_context_stack.back().stream = dynamic_cast<antlr4::TokenStream*>(parser->getInputStream());
  // return parsed tree
  root = parser->topList();
  sl_assert(Utils::root(root) == root);
  s_Root2Context.insert(std::make_pair(root, this));
  return root;
}

// -------------------------------------------------

void ParsingContext::bind()
{
  // push previous
  context_rec rec;
  rec.stream = Utils::getTokenStream();
  rec.lpp    = Utils::getLuaPreProcessor();
  s_context_stack.push_back(rec);
  // set new
  if (!parser.isNull()) {
    Utils::setTokenStream(dynamic_cast<antlr4::TokenStream*>(parser->getInputStream()));
  }
  Utils::setLuaPreProcessor(lpp.raw());
  Algorithm::setLuaPreProcessor(lpp.raw());
  // set as active
  s_ActiveContext.push_back(this);
}

void ParsingContext::unbind()
{
  // pop previous
  Utils::setTokenStream(s_context_stack.back().stream);
  Utils::setLuaPreProcessor(s_context_stack.back().lpp);
  Algorithm::setLuaPreProcessor(s_context_stack.back().lpp);
  s_context_stack.pop_back();
  s_ActiveContext.pop_back();
}

// -------------------------------------------------

ParsingContext::~ParsingContext()
{
  s_Root2Context.erase(root);
}

// -------------------------------------------------
