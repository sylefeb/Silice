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

#include "path.h"

// -------------------------------------------------

class VerilogCompiler
{
private:

  std::vector<std::string>                                           m_Paths;
  std::unordered_map<std::string, AutoPtr<Algorithm> >               m_Algorithms;
  std::unordered_map<std::string, AutoPtr<Module> >                  m_Modules;
  std::unordered_map<std::string, siliceParser::SubroutineContext* > m_Subroutines;
  std::unordered_map<std::string, siliceParser::CircuitryContext* >  m_Circuitries;
  std::unordered_map<std::string, siliceParser::GroupContext* >      m_Groups;
  std::unordered_set<std::string>                                    m_Appends;

  std::string findFile(std::string fname) const
  {
    std::string tmp_fname;

    if (LibSL::System::File::exists(fname.c_str())) {
      return fname;
    }
    for (auto path : m_Paths) {
      tmp_fname = path + "/" + extractFileName(fname);
      if (LibSL::System::File::exists(tmp_fname.c_str())) {
        return tmp_fname;
      }
    }
    for (auto path : m_Paths) {
      tmp_fname = path + "/" + fname;
      if (LibSL::System::File::exists(tmp_fname.c_str())) {
        return tmp_fname;
      }
    }
    return fname;
  }

  void gatherAll(antlr4::tree::ParseTree *tree)
  {
    if (tree == nullptr) {
      return;
    }

    auto toplist = dynamic_cast<siliceParser::TopListContext*>(tree);
    auto alg     = dynamic_cast<siliceParser::AlgorithmContext*>(tree);
    auto circuit = dynamic_cast<siliceParser::CircuitryContext*>(tree);
    auto imprt   = dynamic_cast<siliceParser::ImportvContext*>(tree);
    auto app     = dynamic_cast<siliceParser::AppendvContext*>(tree);
    auto sub     = dynamic_cast<siliceParser::SubroutineContext*>(tree);
    auto group   = dynamic_cast<siliceParser::GroupContext*>(tree);

    if (toplist) {

      // keep going
      for (auto c : tree->children) {
        gatherAll(c);
      }

    } else if (alg) {

      /// algorithm
      std::string name  = alg->IDENTIFIER()->getText();
      std::cerr << "parsing algorithm " << name << std::endl;
      bool autorun      = (name == "main");
      int  stack_size   = DEFAULT_STACK_SIZE;
      std::string clock = ALG_CLOCK;
      std::string reset = ALG_RESET;
      if (alg->algModifiers() != nullptr) {
        for (auto m : alg->algModifiers()->algModifier()) {
          if (m->sclock() != nullptr) {
            clock = m->sclock()->IDENTIFIER()->getText();
          }
          if (m->sreset() != nullptr) {
            reset = m->sreset()->IDENTIFIER()->getText();
          }
          if (m->sautorun() != nullptr) {
            autorun = true;
          }
          if (m->sstacksz() != nullptr) {
            stack_size = atoi(m->sstacksz()->NUMBER()->getText().c_str());
            if (stack_size < 1) {
              throw Fatal("algorithm return stack size should be at least 1 (line %d)!", alg->getStart()->getLine());
            }
          }
        }
      }
      AutoPtr<Algorithm> algorithm(new Algorithm(
        name, clock, reset, autorun, stack_size, 
        m_Modules, m_Subroutines, m_Circuitries, m_Groups)
      );
      if (m_Algorithms.find(name) != m_Algorithms.end()) {
        throw Fatal("an algorithm with same name already exists (line %d)!", alg->getStart()->getLine());
      }
      algorithm->gather(alg->inOutList(),alg->declAndInstrList());
      m_Algorithms.insert(std::make_pair(name,algorithm));

    } else if (circuit) {

      /// circuitry
      std::string name = circuit->IDENTIFIER()->getText();
      if (m_Circuitries.find(name) != m_Circuitries.end()) {
        throw Fatal("a circuitry with same name already exists (line %d)!", circuit->getStart()->getLine());
      }
      m_Circuitries.insert(std::make_pair(name, circuit));

    } else if (group) {

      /// group
      std::string name = group->IDENTIFIER()->getText();
      if (m_Groups.find(name) != m_Groups.end()) {
        throw Fatal("a group with same name already exists (line %d)!", group->getStart()->getLine());
      }
      m_Groups.insert(std::make_pair(name, group));

    } else if (imprt) {

      /// verilog module import
      std::string fname = imprt->FILENAME()->getText();
      fname = fname.substr(1, fname.length() - 2);
      fname = findFile(fname);
      if (!LibSL::System::File::exists(fname.c_str())) {
        throw Fatal("cannot find module file '%s' (line %d)", fname.c_str(), imprt->getStart()->getLine());
      }
      AutoPtr<Module> vmodule(new Module(fname));
      if (m_Modules.find(fname) != m_Modules.end()) {
        throw Fatal("verilog module already imported! (line %d)",imprt->getStart()->getLine());
      }
      std::cerr << "parsing module " << vmodule->name() << std::endl;
      m_Modules.insert(std::make_pair(vmodule->name(), vmodule));

    } else if (app) {

      /// verilog module append
      std::string fname = app->FILENAME()->getText();
      fname = fname.substr(1, fname.length() - 2);
      fname = findFile(fname);
      if (!LibSL::System::File::exists(fname.c_str())) {
        throw Fatal("cannot find module file '%s' (line %d)", fname.c_str(), app->getStart()->getLine());
      }
      m_Appends.insert(fname);

    } else if (sub) {

      /// global subroutine
      std::string name = sub->IDENTIFIER()->getText();
      if (m_Subroutines.find(name) != m_Subroutines.end()) {
        throw Fatal("subroutine with same name already exists! (line %d)", sub->getStart()->getLine());
      }
      m_Subroutines.insert(std::make_pair(sub->IDENTIFIER()->getText(), sub));

    }
  }

  void prepareFramework(const char *fframework,std::string& _lpp,std::string& _verilog)
  {
    // gather 
    // - pre-processor header (all lines starting with $$)
    // - verilog code (all other lines)
    std::ifstream infile(fframework);
    if (!infile) {
      throw Fatal("Cannot open framework file '%s'",fframework);
    }
    std::string line;
    while (std::getline(infile, line)) {
      if (line.substr(0, 2) == "$$") {
        _lpp += line.substr(2) + "\n";
      } else {
        _verilog += line + "\n";
      }
    }
  }

private:

  class ReportError
  {
  private:

    void split(const std::string& s, char delim, std::vector<std::string>& elems)
    {
      std::stringstream ss(s);
      std::string item;
      while (getline(ss, item, delim)) {
        elems.push_back(item);
      }
    }

    void printReport(int line,std::string msg)
    {
      std::vector<std::string> items;
      split(msg, '#', items);
      if (items.size() == 6) {
        std::cerr << std::endl;
        std::cerr << Console::bold << Console::white << "Syntax error line " << line << Console::normal << std::endl;
        std::cerr << std::endl;
        std::cerr << items[2] << std::endl;
        ForIndex(i, std::stoi(items[4])) {
          std::cerr << ' ';
        }
        std::cerr << Console::white << Console::bold;
        ForRange(i, std::stoi(items[4]), std::stoi(items[5])) {
          std::cerr << '^';
        }
        std::cerr << Console::red;
        std::cerr << " " << items[0] << std::endl;
        std::cerr << Console::gray;
        std::cerr << std::endl;
        std::cerr << std::endl;
      } else {
        std::cerr << msg << std::endl;
      }
    }

  public:

    ReportError(int line,std::string msg)
    {
      printReport(line,msg);
    }

  };

  class LexerErrorListener : public antlr4::BaseErrorListener {
  public:
    LexerErrorListener() {}
    virtual void syntaxError(
      antlr4::Recognizer *recognizer,
      antlr4::Token *tk,
      size_t line,
      size_t charPositionInLine,
      const std::string &msg, std::exception_ptr e) override
    {
      std::cerr << Console::red <<
        "[syntax error] line " << line << " : " << msg
        << Console::gray << std::endl;
      throw Fatal(msg.c_str());
    }
  };

  class ParserErrorListener : public antlr4::BaseErrorListener {
  public:
    ParserErrorListener() {}
    virtual void syntaxError(
      antlr4::Recognizer *recognizer, 
      antlr4::Token      *tk, 
      size_t              line, 
      size_t              charPositionInLine,
      const std::string  &msg,
      std::exception_ptr e) override
    {
      ReportError err(line,msg);
      throw Fatal("[parse error]");
    }
  };

  class ParserErrorHandler : public antlr4::DefaultErrorStrategy 
  {
  protected:

    std::string extractCodeAroundToken(std::string file,antlr4::Token* tk, antlr4::TokenStream* tk_stream,int& _offset)
    {
      antlr4::Token* first_tk = tk;
      int index   = first_tk->getTokenIndex();
      int tkline  = first_tk->getLine();
      while (index > 0) {
        first_tk = tk_stream->get(--index);
        if (first_tk->getLine() < tkline) {
          first_tk = tk_stream->get(index + 1);
          break;
        }
      }
      antlr4::Token* last_tk = tk;
      index  = last_tk->getTokenIndex();
      tkline = last_tk->getLine();
      while (index < tk_stream->size()-2) {
        last_tk = tk_stream->get(++index);
        if (last_tk->getLine() > tkline) {
          last_tk = tk_stream->get(index - 1);
          break;
        }
      }
      _offset = first_tk->getCharPositionInLine();
      // now extract from file
      int sidx = first_tk->getStartIndex();
      int eidx = last_tk->getStopIndex();
      {
        FILE* f = fopen(file.c_str(), "rb");
        if (f) {
          char buffer[256];
          fseek(f, sidx, SEEK_SET);
          int read = fread(buffer, 1, min(255, eidx - sidx + 1), f);
          buffer[read] = '\0';
          fclose(f);
          return std::string(buffer);
        }
      }
      return tk_stream->getText(first_tk, last_tk);
    }

    void reportNoViableAlternative(antlr4::Parser *parser, antlr4::NoViableAltException const& ex) override
    {
      std::string msg = "reportNoViableAlternative";
      parser->notifyErrorListeners(ex.getOffendingToken(), msg, std::make_exception_ptr(ex));
    }
    void reportInputMismatch(antlr4::Parser* parser, antlr4::InputMismatchException const& ex) override
    {
      std::string msg  = "unexpected symbol#";
      antlr4::TokenStream* tk_stream = dynamic_cast<antlr4::TokenStream*>(parser->getInputStream());
      if (tk_stream != nullptr) {
        msg += tk_stream->getText(antlr4::misc::Interval{ ex.getOffendingToken()->getStartIndex(), ex.getOffendingToken()->getStopIndex() });
      }
      msg += "#";
      if (tk_stream != nullptr) {
        std::string file = tk_stream->getTokenSource()->getInputStream()->getSourceName();
        int offset = 0;
        std::string line = extractCodeAroundToken(file,ex.getOffendingToken(),tk_stream,offset);
        msg += line;
        msg += "#";
        msg += tk_stream->getText(ex.getOffendingToken(), ex.getOffendingToken());
        msg += "#"; 
        msg += std::to_string(ex.getOffendingToken()->getCharPositionInLine() - offset);
        msg += "#";
        msg += std::to_string(ex.getOffendingToken()->getCharPositionInLine() - offset);
      }
      parser->notifyErrorListeners(ex.getOffendingToken(), msg, std::make_exception_ptr(ex));
    }
    void reportFailedPredicate(antlr4::Parser* parser, antlr4::FailedPredicateException const& ex) override
    {
      std::string msg = "reportFailedPredicate";
      parser->notifyErrorListeners(ex.getOffendingToken(), msg, std::make_exception_ptr(ex));
    }
    void reportUnwantedToken(antlr4::Parser* parser) override
    {
      std::string msg = "reportUnwantedToken";
      antlr4::Token* tk = parser->getCurrentToken();
      parser->notifyErrorListeners(tk, msg, nullptr);
    }
    void reportMissingToken(antlr4::Parser* parser) override
    {
      std::string msg = "reportMissingToken";
      antlr4::Token* tk = parser->getCurrentToken();
      parser->notifyErrorListeners(tk, msg, nullptr);
    }
  };

public:

  /// \brief runs the compiler
  void run(
    const char *fsource, 
    const char *fresult,
    const char *fframework)
  {
    // extract pre-processor header from framework
    std::string framework_lpp, framework_verilog;
    prepareFramework(fframework, framework_lpp, framework_verilog);
    // preprocessor
    LuaPreProcessor lpp;
    std::string preprocessed = std::string(fsource) + ".lpp";
    lpp.addDefinition("FRAMEWORK", fframework);
    lpp.run(fsource, framework_lpp, preprocessed);
    // extract path
    m_Paths = lpp.searchPaths();
    // parse the preprocessed source
    if (LibSL::System::File::exists(preprocessed.c_str())) {
      // initiate parsing
      LexerErrorListener          lexerErrorListener;
      ParserErrorListener         parserErrorListener;
      ParserErrorHandler          parserErrorHandler;
      antlr4::ANTLRFileStream     input(preprocessed);
      siliceLexer                 lexer(&input);
      antlr4::CommonTokenStream   tokens(&lexer);
      siliceParser                parser(&tokens);

      auto err_handler = std::make_shared<ParserErrorHandler>();
      parser.setErrorHandler(err_handler);
      lexer .removeErrorListeners();
      lexer .addErrorListener(&lexerErrorListener);
      parser.removeErrorListeners();
      parser.addErrorListener(&parserErrorListener);

      // analyze
      gatherAll(parser.topList());

      // resolve refs between algorithms and modules
      for (const auto& alg : m_Algorithms) {
        alg.second->resolveAlgorithmRefs(m_Algorithms);
        alg.second->resolveModuleRefs(m_Modules);
      }

      // optimize
      for (const auto& alg : m_Algorithms) {
        alg.second->optimize();
      }

      // save the result
      {
        std::ofstream out(fresult);
        // write framework (top) module
        out << framework_verilog;
        // write includes
        for (auto fname : m_Appends) {
          out << Module::fileToString(fname.c_str()) << std::endl;
        }
        // write imported modules
        for (auto m : m_Modules) {
          m.second->writeModule(out);
        }
        // write algorithms as modules
        for (auto a : m_Algorithms) {
          a.second->writeAsModule(out);
        }
      }

    } else {
      throw Fatal("cannot open source file '%s'", fsource);
    }

  }

};

// -------------------------------------------------
