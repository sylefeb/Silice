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
//                                ... hardcoding ...
// -------------------------------------------------

#include "Algorithm.h"
#include "Module.h"
#include "LuaPreProcessor.h"

// -------------------------------------------------

#include <string>
#include <iostream>
#include <fstream>
#include <regex>
#include <queue>
#include <cstdio>

#include <LibSL/LibSL.h>

namespace Silice {

  // -------------------------------------------------

  class SiliceCompiler
  {
  private:

    std::vector<std::string>                                           m_Paths;
    std::unordered_map<std::string, AutoPtr<Algorithm> >               m_Algorithms;
    std::vector<std::string>                                           m_AlgorithmsInDeclOrder;
    std::unordered_map<std::string, AutoPtr<Module> >                  m_Modules;
    std::vector<std::string>                                           m_ModulesInDeclOrder;
    std::unordered_map<std::string, siliceParser::SubroutineContext* > m_Subroutines;
    std::unordered_map<std::string, siliceParser::CircuitryContext* >  m_Circuitries;
    std::unordered_map<std::string, siliceParser::GroupContext* >      m_Groups;
    std::unordered_map<std::string, siliceParser::IntrfaceContext * > m_Interfaces;
    std::unordered_map<std::string, siliceParser::BitfieldContext* >   m_BitFields;
    std::unordered_set<std::string>                                    m_Appends;
    std::vector<std::string>                                           m_AppendsInDeclOrder;

    const std::vector<std::string> c_DefaultLibraries = { "memory_ports.ice" };

    /// \brief finds a file by checking throughout paths known to be used by the source code
    std::string findFile(std::string fname) const;
    /// \brief gathers all constructs from the source code file
    void gatherAll(antlr4::tree::ParseTree* tree);
    /// \brief prepare the hardware fraemwork before compilation
    void prepareFramework(std::string fframework, std::string& _lpp, std::string& _verilog);

  private:

    /// \brief class for error reporting from ANTL status
    class ReportError
    {
    private:

      void        split(const std::string& s, char delim, std::vector<std::string>& elems) const;
      void        printReport(std::pair<std::string, int> where, std::string msg) const;
      int         lineFromInterval(antlr4::TokenStream *tk_stream, antlr4::misc::Interval interval) const;
      std::string extractCodeBetweenTokens(std::string file, antlr4::TokenStream *tk_stream, int stk, int etk) const;
      std::string extractCodeAroundToken(std::string file, antlr4::Token *tk, antlr4::TokenStream *tk_stream, int &_offset) const;
      std::string prepareMessage(antlr4::TokenStream* tk_stream, antlr4::Token *offender, antlr4::misc::Interval tk_interval) const;

    public:

      ReportError(const LuaPreProcessor& lpp, int line, antlr4::TokenStream* tk_stream,
        antlr4::Token *offender, antlr4::misc::Interval tk_interval, std::string msg);

    };

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

    /// \brief class for ANTLR parsing error reporting
    class ParserErrorListener : public antlr4::BaseErrorListener
    {
    private:
      const LuaPreProcessor &m_PreProcessor;
    public:
      ParserErrorListener(const LuaPreProcessor &pp) : m_PreProcessor(pp) {}
      virtual void syntaxError(
        antlr4::Recognizer* recognizer,
        antlr4::Token* tk,
        size_t              line,
        size_t              charPositionInLine,
        const std::string& msg,
        std::exception_ptr e) override;
    };

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

  public:

    /// \brief runs the compiler
    void run(
      std::string fsource,
      std::string fresult,
      std::string fframework,
      std::string frameworks_dir,
      const std::vector<std::string>& defines);

  };

  // -------------------------------------------------

};
