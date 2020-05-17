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

#include "SiliceCompiler.h"

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

std::string SiliceCompiler::findFile(std::string fname) const
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

// -------------------------------------------------

void SiliceCompiler::gatherAll(antlr4::tree::ParseTree* tree)
{
  if (tree == nullptr) {
    return;
  }

  auto toplist = dynamic_cast<siliceParser::TopListContext*>(tree);
  auto alg = dynamic_cast<siliceParser::AlgorithmContext*>(tree);
  auto circuit = dynamic_cast<siliceParser::CircuitryContext*>(tree);
  auto imprt = dynamic_cast<siliceParser::ImportvContext*>(tree);
  auto app = dynamic_cast<siliceParser::AppendvContext*>(tree);
  auto sub = dynamic_cast<siliceParser::SubroutineContext*>(tree);
  auto group = dynamic_cast<siliceParser::GroupContext*>(tree);

  if (toplist) {

    // keep going
    for (auto c : tree->children) {
      gatherAll(c);
    }

  } else if (alg) {

    /// algorithm
    std::string name = alg->IDENTIFIER()->getText();
    std::cerr << "parsing algorithm " << name << std::endl;
    bool autorun = (name == "main");
    int  stack_size = DEFAULT_STACK_SIZE;
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
    algorithm->gather(alg->inOutList(), alg->declAndInstrList());
    m_Algorithms.insert(std::make_pair(name, algorithm));

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
      throw Fatal("verilog module already imported! (line %d)", imprt->getStart()->getLine());
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

// -------------------------------------------------

void SiliceCompiler::prepareFramework(const char* fframework, std::string& _lpp, std::string& _verilog)
{
  // gather 
  // - pre-processor header (all lines starting with $$)
  // - verilog code (all other lines)
  std::ifstream infile(fframework);
  if (!infile) {
    throw Fatal("Cannot open framework file '%s'", fframework);
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

// -------------------------------------------------

void SiliceCompiler::run(
  const char* fsource,
  const char* fresult,
  const char* fframework)
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
    LexerErrorListener          lexerErrorListener(lpp);
    ParserErrorListener         parserErrorListener(lpp);
    antlr4::ANTLRFileStream     input(preprocessed);
    siliceLexer                 lexer(&input);
    antlr4::CommonTokenStream   tokens(&lexer);
    siliceParser                parser(&tokens);

    auto err_handler = std::make_shared<ParserErrorHandler>();
    parser.setErrorHandler(err_handler);
    lexer.removeErrorListeners();
    lexer.addErrorListener(&lexerErrorListener);
    parser.removeErrorListeners();
    parser.addErrorListener(&parserErrorListener);

    try {

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
    
    } catch (Algorithm::LanguageError& le) {

      ReportError err(lpp, le.line(), dynamic_cast<antlr4::TokenStream*>(parser.getInputStream()), le.token(), le.interval(), le.message());

    }

  } else {
    throw Fatal("cannot open source file '%s'", fsource);
  }

}

// -------------------------------------------------

void SiliceCompiler::ReportError::split(const std::string& s, char delim, std::vector<std::string>& elems)
{
  std::stringstream ss(s);
  std::string item;
  while (getline(ss, item, delim)) {
    elems.push_back(item);
  }
}

// -------------------------------------------------

static int numLinesIn(std::string l)
{
  return (int)std::count(l.begin(), l.end(), '\n');
}

// -------------------------------------------------

void SiliceCompiler::ReportError::printReport(std::pair<std::string, int> where, std::string msg)
{
  std::cerr << Console::bold << Console::white << "----------<<<<< error >>>>>----------" << std::endl << std::endl;
  if (where.second > -1) {
    std::cerr 
      << "=> file: " << where.first << std::endl
      << "=> line: " << where.second << std::endl
      << Console::normal << std::endl;
  }
  std::vector<std::string> items;
  split(msg, '#', items);
  if (items.size() == 5) {
    std::cerr << std::endl;
    std::cerr << Console::white << Console::bold;
    std::cerr << items[1] << std::endl;
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
      std::cerr << std::endl;
      std::cerr << Console::yellow << Console::bold;
      std::cerr << "--->";
    }
    std::cerr << Console::red;
    std::cerr << " " << items[0] << std::endl;
    std::cerr << Console::gray;
    std::cerr << std::endl;
  } else {
    std::cerr << Console::red << Console::bold;
    std::cerr << msg << std::endl;
    std::cerr << Console::normal;
    std::cerr << std::endl;
  }
}

// -------------------------------------------------

#if !defined(_WIN32)  && !defined(_WIN64)
#define fopen_s(f,n,m) ((*f) = fopen(n,m))
#endif

// -------------------------------------------------

std::string SiliceCompiler::ReportError::extractCodeBetweenTokens(std::string file, antlr4::TokenStream *tk_stream, int stk, int etk)
{
  int sidx = (int)tk_stream->get(stk)->getStartIndex();
  int eidx = (int)tk_stream->get(etk)->getStopIndex();
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
  return tk_stream->getText(tk_stream->get(stk), tk_stream->get(etk));
}

// -------------------------------------------------

std::string SiliceCompiler::ReportError::extractCodeAroundToken(std::string file, antlr4::Token* tk, antlr4::TokenStream* tk_stream, int& _offset)
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

std::string SiliceCompiler::ReportError::prepareMessage(antlr4::TokenStream* tk_stream,antlr4::Token* offender,antlr4::misc::Interval interval)
{
  std::string msg = "";
  if (tk_stream != nullptr && (offender != nullptr || !(interval == antlr4::misc::Interval::INVALID))) {
    msg = "#";
    std::string file = tk_stream->getTokenSource()->getInputStream()->getSourceName();
    int offset = 0;
    std::string line;
    if (offender != nullptr) {
      tk_stream->getText(offender, offender); // this seems required to refresh the steam? TODO FIXME investigate
      line = extractCodeAroundToken(file, offender, tk_stream, offset);
    } else if (!(interval == antlr4::misc::Interval::INVALID)) {
      line = extractCodeBetweenTokens(file, tk_stream, (int)interval.a, (int)interval.b);
      offset = (int)tk_stream->get(interval.a)->getStartIndex();
    }
    msg += line;
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

SiliceCompiler::ReportError::ReportError(const LuaPreProcessor& lpp, 
  int line, antlr4::TokenStream* tk_stream, 
  antlr4::Token *offender, antlr4::misc::Interval interval, std::string msg)
{
  msg += prepareMessage(tk_stream,offender,interval);
  printReport(lpp.lineAfterToFileAndLineBefore((int)line), msg);
}

// -------------------------------------------------

void SiliceCompiler::LexerErrorListener::syntaxError(
  antlr4::Recognizer* recognizer,
  antlr4::Token* tk,
  size_t line,
  size_t charPositionInLine,
  const std::string& msg, std::exception_ptr e)
{
  ReportError err(m_PreProcessor, (int)line, nullptr, nullptr, antlr4::misc::Interval(), msg);
  throw Fatal("[lexical error]");
}

// -------------------------------------------------

void SiliceCompiler::ParserErrorListener::syntaxError(
  antlr4::Recognizer* recognizer,
  antlr4::Token*      tk,
  size_t              line,
  size_t              charPositionInLine,
  const std::string&  msg,
  std::exception_ptr  e)
{
  ReportError err(m_PreProcessor, (int)line, dynamic_cast<antlr4::TokenStream*>(recognizer->getInputStream()), tk, antlr4::misc::Interval::INVALID, msg);
  throw Fatal("[syntax error]");
}


void SiliceCompiler::ParserErrorHandler::reportNoViableAlternative(antlr4::Parser* parser, antlr4::NoViableAltException const& ex)
{
  std::string msg = "surprised to find this here";
  parser->notifyErrorListeners(ex.getOffendingToken(), msg, std::make_exception_ptr(ex));
}

void SiliceCompiler::ParserErrorHandler::reportInputMismatch(antlr4::Parser* parser, antlr4::InputMismatchException const& ex)
{
  std::string msg = "expecting something else";
  parser->notifyErrorListeners(ex.getOffendingToken(), msg, std::make_exception_ptr(ex));
}

void SiliceCompiler::ParserErrorHandler::reportFailedPredicate(antlr4::Parser* parser, antlr4::FailedPredicateException const& ex)
{
  std::string msg = "surprised to find this here";
  parser->notifyErrorListeners(ex.getOffendingToken(), msg, std::make_exception_ptr(ex));
}

void SiliceCompiler::ParserErrorHandler::reportUnwantedToken(antlr4::Parser* parser)
{
  std::string msg = "this should not be here";
  antlr4::Token* tk = parser->getCurrentToken();
  parser->notifyErrorListeners(tk, msg, nullptr);
}

void SiliceCompiler::ParserErrorHandler::reportMissingToken(antlr4::Parser* parser)
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
