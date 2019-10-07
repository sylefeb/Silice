#pragma once
// -------------------------------------------------
//
// FPGA Simple Language
//
// (c) Sylvain Lefebvre 2019
// 
//                                ... hardcoding ...
// -------------------------------------------------
/*

*/

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

#include <LibSL/LibSL.h>

#include "path.h"

// -------------------------------------------------

using namespace antlr4;
using namespace std;

// -------------------------------------------------

class VerilogCompiler
{
private:

  std::map<std::string, AutoPtr<Algorithm> >       m_Algorithms;
  std::map<std::string, AutoPtr<Module> >          m_Modules;
  std::set<std::string>                            m_Appends;

  void gatherAlgorithms(tree::ParseTree *tree)
  {
    if (tree == nullptr) {
      return;
    }

    auto alglist = dynamic_cast<siliceParser::AlgorithmListContext*>(tree);
    auto alg     = dynamic_cast<siliceParser::AlgorithmContext*>(tree);
    auto imprt   = dynamic_cast<siliceParser::ImportvContext*>(tree);
    auto app     = dynamic_cast<siliceParser::AppendvContext*>(tree);

    if (alglist) {
      // keep going
      for (auto c : tree->children) {
        gatherAlgorithms(c);
      }
    } else if (alg) {
      // algorithm
      std::string name  = alg->IDENTIFIER()->getText();
      cerr << "parsing algorithm " << name << std::endl;
      bool autorun      = (name == "main");
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
        }
      }
      AutoPtr<Algorithm> algorithm(new Algorithm(name, clock, reset, autorun, m_Modules));
      if (m_Algorithms.find(name) != m_Algorithms.end()) {
        throw std::runtime_error("algorithm with same name already exists!");
      }
      algorithm->gather(alg->inOutList(),alg->declAndInstrList());
      m_Algorithms.insert(std::make_pair(name,algorithm));
    } else if (imprt) {
      // verilog import
      std::string fname = imprt->FILENAME()->getText();
      fname = fname.substr(1, fname.length() - 2);
      AutoPtr<Module> vmodule(new Module(fname));
      if (m_Modules.find(fname) != m_Modules.end()) {
        throw std::runtime_error("verilog module already imported!");
      }
      cerr << "parsing module " << vmodule->name() << std::endl;
      m_Modules.insert(std::make_pair(vmodule->name(), vmodule));
    } else if (app) {
      // file include
      std::string fname = app->FILENAME()->getText();
      fname = fname.substr(1, fname.length() - 2);
      m_Appends.insert(fname);
    }
  }

private:

  class LexerErrorListener : public BaseErrorListener {
  public:
    LexerErrorListener() {}
    virtual void syntaxError(
      Recognizer *recognizer,
      Token *offendingSymbol,
      size_t line,
      size_t charPositionInLine,
      const std::string &msg, std::exception_ptr e) override
    {
      cerr << Console::red <<
        "[syntax error] line " << line << " : " << msg
        << Console::gray << endl;
      throw Fatal(msg.c_str());
    }
  };

  class ParserErrorListener : public BaseErrorListener {
  public:
    ParserErrorListener() {}
    virtual void syntaxError(Recognizer *recognizer, Token *offendingSymbol, size_t line, size_t charPositionInLine,
      const std::string &msg, std::exception_ptr e) override
    {
      cerr << Console::red <<
        "[parse error] line " << line << " : " << msg
        << Console::gray << endl;
      throw Fatal(msg.c_str());
    }
  };

public:

  /// \brief runs the compiler
  void run(
    const char *fsource, 
    const char *fresult,
    const char *fframework)
  {
    // preprocessor
    LppPreProcessor lpp;
    std::string preprocessed = std::string(fsource) + ".lpp";
    lpp.execute(fsource, preprocessed);
    // parse the preprocessed source
    ifstream file(preprocessed);
    if (file) {
      // initiate parsing
      LexerErrorListener  lexerErrorListener;
      ParserErrorListener parserErrorListener;
      ANTLRInputStream    input(file);
      siliceLexer         lexer(&input);
      CommonTokenStream   tokens(&lexer);
      siliceParser        parser(&tokens);
      file.close();

      lexer .removeErrorListeners();
      lexer .addErrorListener(&lexerErrorListener);
      parser.removeErrorListeners();
      parser.addErrorListener(&parserErrorListener);

      // analyze
      gatherAlgorithms(parser.algorithmList());

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
        ofstream out(fresult);
        // write includes
        for (auto i : m_Appends) {
          std::string fname = std::string(SRC_PATH "/tests/") + i;
          out << loadFileIntoString(fname.c_str()) << endl;
        }
        // write imported modules
        for (auto m : m_Modules) {
          m.second->writeModule(out);
        }
        // write algorithms as modules
        for (auto a : m_Algorithms) {
          a.second->writeAsModule(out);
        }
        // write top module
        out << loadFileIntoString(fframework);
      }

    } else {
      throw std::runtime_error("cannot open source file");
    }

  }

};

// -------------------------------------------------
