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

#include "ParsingErrors.h"
#include "LuaPreProcessor.h"

namespace Silice {

  // -------------------------------------------------

  /// \brief class storing the parsing context
  class ParsingContext
  {
  private:

    // stack of active contexts during code generation
    static std::vector<ParsingContext*>                       s_ActiveContext;
    // records which root was produced by which context parse() call
    // this is used to find the context and token stream, when localizing tokens in source
    static std::map<antlr4::tree::ParseTree*,ParsingContext*> s_Root2Context;

  public:

    std::string                          fresult;
    std::string                          framework_verilog;
    std::vector<std::string>             defines;
    AutoPtr<LuaPreProcessor>             lpp;
    AutoPtr<LexerErrorListener>          lexerErrorListener;
    AutoPtr<ParserErrorListener>         parserErrorListener;
    AutoPtr<antlr4::ANTLRFileStream>     input;
    AutoPtr<siliceLexer>                 lexer;
    AutoPtr<antlr4::CommonTokenStream>   tokens;
    AutoPtr<siliceParser>                parser;
    antlr4::tree::ParseTree             *root = nullptr;
    std::shared_ptr<ParserErrorHandler>  err_handler;
    std::vector<LibSL::Math::v3i>        lineRemapping; // [0] is line after, [1] is file id, [2] is line before

    ParsingContext(
      std::string              fresult_,
      AutoPtr<LuaPreProcessor> lpp_,
      std::string              framework_verilog_,
      const std::vector<std::string>& defines_);

    antlr4::tree::ParseTree* parse(std::string preprocessed);

    ~ParsingContext();

    static ParsingContext *activeContext() {
      if (s_ActiveContext.empty()) return nullptr; else return s_ActiveContext.back();
    }
    static ParsingContext *rootContext(antlr4::tree::ParseTree *root) {
      return s_Root2Context.at(Utils::root(root));
    }

    void bind();
    void unbind();
  };

  // -------------------------------------------------

};
