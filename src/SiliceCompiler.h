/*

    Silice FPGA language and compiler
    (c) Sylvain Lefebvre - @sylefeb

This work and all associated files are under the

     GNU AFFERO GENERAL PUBLIC LICENSE
        Version 3, 19 November 2007
        
A copy of the license full text is included in 
the distribution, please refer to it for details.

(header_1_0)
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
    std::unordered_map<std::string, siliceParser::BitfieldContext* >   m_BitFields;
    std::unordered_set<std::string>                                    m_Appends;
    std::vector<std::string>                                           m_AppendsInDeclOrder;

    /// \brief finds a file by checking throughout paths known to be used by the source code
    std::string findFile(std::string fname) const;
    /// \brief gathers all constructs from the source code file
    void gatherAll(antlr4::tree::ParseTree* tree);
    /// \brief prepare the hardware fraemwork before compilation
    void prepareFramework(const char* fframework, std::string& _lpp, std::string& _verilog);

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
      const char *fsource,
      const char *fresult,
      const char *fframework,
      const std::vector<std::string>& defines);

  };

  // -------------------------------------------------

};
