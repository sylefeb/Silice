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
//                                ... hardcoding ...
// -------------------------------------------------

#include "SiliceCompiler.h"
#include "Config.h"
#include "ExpressionLinter.h"
#include "RISCVSynthesizer.h"

// -------------------------------------------------

#include <string>
#include <iostream>
#include <fstream>
#include <regex>
#include <queue>
#include <cstdio>

#include <LibSL/LibSL.h>

using namespace Silice;

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

  auto toplist  = dynamic_cast<siliceParser::TopListContext*>(tree);
  auto alg      = dynamic_cast<siliceParser::AlgorithmContext*>(tree);
  auto circuit  = dynamic_cast<siliceParser::CircuitryContext*>(tree);
  auto imprt    = dynamic_cast<siliceParser::ImportvContext*>(tree);
  auto app      = dynamic_cast<siliceParser::AppendvContext*>(tree);
  auto sub      = dynamic_cast<siliceParser::SubroutineContext*>(tree);
  auto group    = dynamic_cast<siliceParser::GroupContext*>(tree);
  auto intrface = dynamic_cast<siliceParser::IntrfaceContext *>(tree);
  auto bitfield = dynamic_cast<siliceParser::BitfieldContext*>(tree);
  auto riscv    = dynamic_cast<siliceParser::RiscvContext *>(tree);

  if (toplist) {

    // keep going
    for (auto c : tree->children) {
      gatherAll(c);
    }

  } else if (alg) {

    /// algorithm
    std::string name = alg->IDENTIFIER()->getText();
    std::cerr << "parsing algorithm " << name << nxl;
    bool autorun = (name == "main");
    bool onehot = false;
    std::string formalDepth = "";
    std::string formalTimeout = "";
    std::vector<std::string> formalModes{};
    std::string clock = ALG_CLOCK;
    std::string reset = ALG_RESET;
    bool hasHash = alg->HASH() != nullptr;
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
        if (m->sonehot() != nullptr) {
          onehot = true;
        }
        if (m->sstacksz() != nullptr) {
          // deprecated, ignore
        }
        if (m->sformdepth() != nullptr) {
          formalDepth = m->sformdepth()->NUMBER()->getText();
        }
        if (m->sformtimeout() != nullptr) {
          formalTimeout = m->sformtimeout()->NUMBER()->getText();
        }
        if (m->sformmode() != nullptr) {
          for (auto i : m->sformmode()->IDENTIFIER()) {
            std::string mode = i->getText();
            if (mode != "bmc" && mode != "tind" && mode != "cover") {
              throw Fatal("Unknown formal mode '%s' (line %d).", mode.c_str(), (int)m->sformmode()->getStart()->getLine());
            }
            formalModes.push_back(mode);
          }
        }
      }
    }
    if (formalModes.empty()) {
      // default to a simple BMC if no mode is specified
      formalModes.push_back("bmc");
    }

    AutoPtr<Algorithm> algorithm(new Algorithm(
      name, hasHash, clock, reset, autorun, onehot, formalDepth, formalTimeout, formalModes,
      m_Modules, m_Algorithms, m_Subroutines, m_Circuitries, m_Groups, m_Interfaces, m_BitFields)
    );
    if (m_Algorithms.find(name) != m_Algorithms.end()) {
      throw Fatal("an algorithm with same name already exists (line %d)!", (int)alg->getStart()->getLine());
    }
    algorithm->gather(alg->inOutList(), alg->declAndInstrList());
    m_Algorithms.insert(std::make_pair(name, algorithm));
    m_AlgorithmsInDeclOrder.push_back(name);

  } else if (circuit) {

    /// circuitry
    std::string name = circuit->IDENTIFIER()->getText();
    if (m_Circuitries.find(name) != m_Circuitries.end()) {
      throw Fatal("a circuitry with same name already exists (line %d)!", (int)circuit->getStart()->getLine());
    }
    m_Circuitries.insert(std::make_pair(name, circuit));

  } else if (group) {

    /// group
    std::string name = group->IDENTIFIER()->getText();
    if (m_Groups.find(name) != m_Groups.end()) {
      throw Fatal("a group with same name already exists (line %d)!", (int)group->getStart()->getLine());
    }
    m_Groups.insert(std::make_pair(name, group));

  } else if (intrface) {

    /// interface
    std::string name = intrface->IDENTIFIER()->getText();
    if (m_Interfaces.find(name) != m_Interfaces.end()) {
      throw Fatal("an interface with same name already exists (line %d)!", (int)intrface->getStart()->getLine());
    }
    m_Interfaces.insert(std::make_pair(name, intrface));

  } else if (bitfield) {

    /// bitfield
    std::string name = bitfield->IDENTIFIER()->getText();
    if (m_BitFields.find(name) != m_BitFields.end()) {
      throw Fatal("a bitfield with same name already exists (line %d)!", (int)bitfield->getStart()->getLine());
    }
    m_BitFields.insert(std::make_pair(name, bitfield));

  } else if (imprt) {

    /// verilog module import
    std::string fname = imprt->FILENAME()->getText();
    fname = fname.substr(1, fname.length() - 2);
    fname = findFile(fname);
    if (!LibSL::System::File::exists(fname.c_str())) {
      throw Fatal("cannot find module file '%s' (line %d)", fname.c_str(), (int)imprt->getStart()->getLine());
    }
    AutoPtr<Module> vmodule(new Module(fname));
    if (m_Modules.find(fname) != m_Modules.end()) {
      throw Fatal("verilog module already imported! (line %d)", (int)imprt->getStart()->getLine());
    }
    std::cerr << "parsing module " << vmodule->name() << nxl;
    m_Modules.insert(std::make_pair(vmodule->name(), vmodule));
    m_ModulesInDeclOrder.push_back(vmodule->name());

  } else if (app) {

    /// verilog module append
    std::string fname = app->FILENAME()->getText();
    fname = fname.substr(1, fname.length() - 2);
    fname = findFile(fname);
    if (!LibSL::System::File::exists(fname.c_str())) {
      throw Fatal("cannot find module file '%s' (line %d)", fname.c_str(), (int)app->getStart()->getLine());
    }
    m_Appends.insert(fname);
    m_AppendsInDeclOrder.push_back(fname);

  } else if (sub) {

    /// global subroutine
    std::string name = sub->IDENTIFIER()->getText();
    if (m_Subroutines.find(name) != m_Subroutines.end()) {
      throw Fatal("subroutine with same name already exists! (line %d)", (int)sub->getStart()->getLine());
    }
    m_Subroutines.insert(std::make_pair(sub->IDENTIFIER()->getText(), sub));

  } else if (riscv) {

    /// RISC-V
    AutoPtr<RISCVSynthesizer> riscv(new RISCVSynthesizer(riscv));

  }
}

// -------------------------------------------------

void SiliceCompiler::prepareFramework(std::string fframework, std::string& _lpp, std::string& _verilog)
{
  // if we don't have a framework (as for the formal board),
  // don't try to open a file located at the empty path "".
  if (fframework.empty())
    return;

  // gather 
  // - pre-processor header (all lines starting with $$)
  // - verilog code (all other lines)
  std::ifstream infile(fframework);
  if (!infile) {
    throw Fatal("Cannot open framework file '%s'", fframework.c_str());
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
  std::string fsource,
  std::string fresult,
  std::string fframework,
  std::string frameworks_dir,
  const std::vector<std::string>& defines)
{
  // determine frameworks dir if needed
  if (frameworks_dir.empty()) {
    frameworks_dir = std::string(LibSL::System::Application::executablePath()) + "../frameworks/";
  }
  /*
  std::cerr << Console::white << std::setw(30) << "framework directory" << " = ";
  std::cerr << Console::yellow << std::setw(30) << frameworks_dir << nxl;
  std::cerr << Console::white << std::setw(30) << "framework file" << " = ";
  std::cerr << Console::yellow << std::setw(30) << fframework << nxl;
  std::cerr << Console::gray;
  */
  // extract pre-processor header from framework
  std::string framework_lpp, framework_verilog;
  prepareFramework(fframework, framework_lpp, framework_verilog);
  // produce header
  // -> pre-processor code from framework
  std::string header = framework_lpp;
  // -> cmd line defines
  for (auto d : defines) {
    header = d + "\n" + header;
  }
  // add framework path to config
  CONFIG.keyValues()["framework_file"] = fframework;
  CONFIG.keyValues()["frameworks_dir"] = frameworks_dir;
  CONFIG.keyValues()["templates_path"] = frameworks_dir + "/templates";
  CONFIG.keyValues()["libraries_path"] = frameworks_dir + "/libraries";
  // preprocessor
  LuaPreProcessor lpp;
  lpp.enableFilesReport(fresult + ".files.log");
  std::string preprocessed = std::string(fsource) + ".lpp";
  lpp.run(fsource, c_DefaultLibraries, header, preprocessed);
  // display config
  CONFIG.print();
  // extract paths
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

    RISCVSynthesizer::setTokenStream(dynamic_cast<antlr4::TokenStream*>(parser.getInputStream()));
    ExpressionLinter::setTokenStream(dynamic_cast<antlr4::TokenStream*>(parser.getInputStream()));
    ExpressionLinter::setLuaPreProcessor(&lpp);
    Algorithm::setLuaPreProcessor(&lpp);

    try {

      // analyze
      gatherAll(parser.topList());

      // resolve refs between algorithms and modules
      for (const auto& alg : m_Algorithms) {
        alg.second->resolveAlgorithmRefs(m_Algorithms);
        alg.second->resolveModuleRefs(m_Modules);
      }

      // save the result
      {
        std::ofstream out(fresult);
        // wrtie cmd line defines
        for (auto d : defines) {
          auto eq = d.find('=');
          if (eq != std::string::npos) {
            out << "`define " << d.substr(0,eq) << " " << d.substr(eq+1) << nxl;
          }
        }
        // write framework (top) module
        out << framework_verilog;
        // write includes
        for (auto fname : m_AppendsInDeclOrder) {
          out << Module::fileToString(fname.c_str()) << nxl;
        }
        // write imported modules
        for (auto miordr : m_ModulesInDeclOrder) {
          auto m = m_Modules.at(miordr);
          m->writeModule(out);
        }

        if (m_Algorithms.count("main") > 0) {
          // ask for reports
          m_Algorithms["main"]->enableReporting(fresult);
          // write top algorithm (recurses from there)
          m_Algorithms["main"]->writeAsModule("", out);
        }

        for (auto const &[algname, alg] : m_Algorithms) {
          if (alg->isFormal()) {
            alg->enableReporting(fresult);
            alg->writeAsModule("formal_" + algname + "$", out);
          }
        }
      }
    
    } catch (Algorithm::LanguageError& le) {

      ReportError err(lpp, le.line(), dynamic_cast<antlr4::TokenStream*>(parser.getInputStream()), le.token(), le.interval(), le.message());
      throw Fatal("Silice compiler stopped");

    }

    RISCVSynthesizer::setTokenStream(nullptr);
    ExpressionLinter::setTokenStream(nullptr);
    ExpressionLinter::setLuaPreProcessor(nullptr);
    Algorithm::setLuaPreProcessor(nullptr);

  } else {
    throw Fatal("cannot open source file '%s'", fsource.c_str());
  }

}

// -------------------------------------------------

void SiliceCompiler::ReportError::split(const std::string& s, char delim, std::vector<std::string>& elems) const
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

void SiliceCompiler::ReportError::printReport(std::pair<std::string, int> where, std::string msg) const
{
  std::cerr << Console::bold << Console::white << "----------<<<<< error >>>>>----------" << nxl << nxl;
  if (where.second > -1) {
    std::cerr 
      << "=> file: " << where.first << nxl
      << "=> line: " << where.second << nxl
      << Console::normal << nxl;
  }
  std::vector<std::string> items;
  split(msg, '#', items);
  if (items.size() == 5) {
    std::cerr << nxl;
    std::cerr << Console::white << Console::bold;
    std::cerr << items[1] << nxl;
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
      std::cerr << nxl;
      std::cerr << Console::yellow << Console::bold;
      std::cerr << "--->";
    }
    std::cerr << Console::red;
    std::cerr << " " << items[0] << nxl;
    std::cerr << Console::gray;
    std::cerr << nxl;
  } else {
    std::cerr << Console::red << Console::bold;
    std::cerr << msg << nxl;
    std::cerr << Console::normal;
    std::cerr << nxl;
  }
}

// -------------------------------------------------

#if !defined(_WIN32)  && !defined(_WIN64)
#define fopen_s(f,n,m) ((*f) = fopen(n,m))
#endif

// -------------------------------------------------

std::string SiliceCompiler::ReportError::extractCodeBetweenTokens(std::string file, antlr4::TokenStream *tk_stream, int stk, int etk) const
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

std::string SiliceCompiler::ReportError::extractCodeAroundToken(std::string file, antlr4::Token* tk, antlr4::TokenStream* tk_stream, int& _offset) const
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

std::string SiliceCompiler::ReportError::prepareMessage(antlr4::TokenStream* tk_stream,antlr4::Token* offender,antlr4::misc::Interval interval) const
{
  std::string msg = "";
  if (tk_stream != nullptr && (offender != nullptr || !(interval == antlr4::misc::Interval::INVALID))) {
    msg = "#";
    std::string file = tk_stream->getTokenSource()->getInputStream()->getSourceName();
    int offset = 0;
    std::string codeline;
    if (offender != nullptr) {
      tk_stream->getText(offender, offender); // this seems required to refresh the steam? TODO FIXME investigate
      codeline = extractCodeAroundToken(file, offender, tk_stream, offset);
    } else if (!(interval == antlr4::misc::Interval::INVALID)) {
      if (interval.a > interval.b) {
        std::swap(interval.a, interval.b);
      }
      codeline = extractCodeBetweenTokens(file, tk_stream, (int)interval.a, (int)interval.b);
      offset = (int)tk_stream->get(interval.a)->getStartIndex();
    }
    msg += codeline;
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

int SiliceCompiler::ReportError::lineFromInterval(antlr4::TokenStream *tk_stream,antlr4::misc::Interval interval) const
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

SiliceCompiler::ReportError::ReportError(const LuaPreProcessor& lpp, 
  int line, antlr4::TokenStream* tk_stream, 
  antlr4::Token *offender, antlr4::misc::Interval interval, std::string msg)
{
  msg += prepareMessage(tk_stream,offender,interval);
  if (line == -1) {
    line = lineFromInterval(tk_stream,interval);
  }
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
