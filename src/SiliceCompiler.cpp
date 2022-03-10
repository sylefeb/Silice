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
#include "Utils.h"

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

std::string SiliceCompiler::findFile(std::string fname) const
{
  std::string tmp_fname;

  if (LibSL::System::File::exists(fname.c_str())) {
    return fname;
  }
  if (!m_Context.isNull()) {
    for (auto path : m_Context->lpp->searchPaths()) {
      tmp_fname = path + "/" + extractFileName(fname);
      if (LibSL::System::File::exists(tmp_fname.c_str())) {
        return tmp_fname;
      }
    }
    for (auto path : m_Context->lpp->searchPaths()) {
      tmp_fname = path + "/" + fname;
      if (LibSL::System::File::exists(tmp_fname.c_str())) {
        return tmp_fname;
      }
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
  auto unit     = dynamic_cast<siliceParser::UnitContext *>(tree);

  if (toplist) {

    // keep going
    for (auto c : tree->children) {
      gatherAll(c);
    }

  } else if (alg || unit) {

    /// algorithm or unit
    std::string name;
    bool hasHash;
    siliceParser::BpModifiersContext *mods = nullptr;
    if (alg) {
      name    = alg->IDENTIFIER()->getText();
      hasHash = alg->HASH() != nullptr;
      mods    = alg->bpModifiers();
    } else {
      name    = unit->IDENTIFIER()->getText();
      hasHash = unit->HASH() != nullptr;
      mods    = unit->bpModifiers();
    }
    std::cerr << "parsing algorithm " << name << nxl;
    bool autorun = (name == "main"); // main always autoruns
    bool onehot  = false;
    std::string formalDepth = "";
    std::string formalTimeout = "";
    std::vector<std::string> formalModes{};
    std::string clock = ALG_CLOCK;
    std::string reset = ALG_RESET;
    if (mods != nullptr) {
      for (auto m : mods->bpModifier()) {
        if (m->sclock() != nullptr) {
          clock = m->sclock()->IDENTIFIER()->getText();
        }
        if (m->sreset() != nullptr) {
          reset = m->sreset()->IDENTIFIER()->getText();
        }
        if (m->sautorun() != nullptr) {
          if (unit) {
            throw Fatal("Unit cannot use the 'autorun' modifier, apply it to the internal algorithm block (line %d).",
              (int)m->sautorun()->getStart()->getLine());
          }
          autorun = true;
        }
        if (m->sonehot() != nullptr) {
          if (unit) {
            throw Fatal("Unit cannot use the 'onehot' modifier, apply it to the internal algorithm block (line %d).",
              (int)m->sonehot()->getStart()->getLine());
          }
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
      m_Blueprints, m_Subroutines, m_Circuitries, m_Groups, m_Interfaces, m_BitFields)
    );
    if (m_Blueprints.find(name) != m_Blueprints.end()) {
      throw Fatal("a unit, algorithm or module with the same name already exists (line %d)!", (int)alg->getStart()->getLine());
    }
    if (alg) {
      algorithm->gather(alg->inOutList(), alg->declAndInstrList());
    } else {
      algorithm->gather(unit->inOutList(), unit->unitBlocks());
    }
    m_Blueprints.insert(std::make_pair(name, algorithm));
    m_BlueprintsInDeclOrder.push_back(name);

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
    if (m_Blueprints.find(fname) != m_Blueprints.end()) {
      throw Fatal("an algorithm or module with the same name already exists (line %d)!", (int)imprt->getStart()->getLine());
    }
    std::cerr << "parsing module " << vmodule->name() << nxl;
    m_Blueprints.insert(std::make_pair(vmodule->name(), vmodule));
    m_BlueprintsInDeclOrder.push_back(vmodule->name());

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
    AutoPtr<RISCVSynthesizer> rv(new RISCVSynthesizer(riscv));
    m_Blueprints.insert(std::make_pair(riscv->IDENTIFIER()->getText(), rv));
    m_BlueprintsInDeclOrder.push_back(riscv->IDENTIFIER()->getText());

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

SiliceCompiler::ParsingContext::ParsingContext(
  std::string              fresult_,
  AutoPtr<LuaPreProcessor> lpp_,
  std::string              preprocessed,
  std::string              framework_verilog_,
  const std::vector<std::string>& defines_)
{
  fresult = fresult_;
  framework_verilog = framework_verilog_;
  defines = defines_;
  lpp = lpp_;
  // initiate parsing
  lexerErrorListener  = AutoPtr<LexerErrorListener>(new LexerErrorListener(*lpp));
  parserErrorListener = AutoPtr<ParserErrorListener>(new ParserErrorListener(*lpp));
  input  = AutoPtr<antlr4::ANTLRFileStream>(new antlr4::ANTLRFileStream(preprocessed));
  lexer  = AutoPtr<siliceLexer>(new siliceLexer(input.raw()));
  tokens = AutoPtr<antlr4::CommonTokenStream>(new antlr4::CommonTokenStream(lexer.raw()));
  parser = AutoPtr<siliceParser>(new siliceParser(tokens.raw()));
  err_handler = std::make_shared<ParserErrorHandler>();
  parser->setErrorHandler(err_handler);
  lexer->removeErrorListeners();
  lexer->addErrorListener(lexerErrorListener.raw());
  parser->removeErrorListeners();
  parser->addErrorListener(parserErrorListener.raw());
}

void SiliceCompiler::ParsingContext::bind()
{
  Utils::setTokenStream(dynamic_cast<antlr4::TokenStream*>(parser->getInputStream()));
  Utils::setLuaPreProcessor(lpp.raw());
  Algorithm::setLuaPreProcessor(lpp.raw());
}

void SiliceCompiler::ParsingContext::unbind()
{
  Utils::setTokenStream(nullptr);
  Utils::setLuaPreProcessor(nullptr);
  Algorithm::setLuaPreProcessor(nullptr);
}

SiliceCompiler::ParsingContext::~ParsingContext()
{

}

// -------------------------------------------------

void SiliceCompiler::parse(
  std::string fsource,
  std::string fresult,
  std::string fframework,
  std::string frameworks_dir,
  const std::vector<std::string>& defines)
{
  // check for double call
  if (!m_Context.isNull()) {
    throw Fatal("[SiliceCompiler::parse] cannot parse a second time");
  }
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
  // display config
  CONFIG.print();
  // run preprocessor
  AutoPtr<LuaPreProcessor> lpp(new LuaPreProcessor());
  lpp->enableFilesReport(fresult + ".files.log");
  std::string preprocessed = std::string(fsource) + ".lpp";
  lpp->run(fsource, c_DefaultLibraries, header, preprocessed);
  // parse the preprocessed source, if succeeded
  if (LibSL::System::File::exists(preprocessed.c_str())) {

    try {

      // create parsing context
      m_Context = AutoPtr<ParsingContext>(new ParsingContext(
        fresult, lpp, preprocessed, framework_verilog, defines));
      m_Context->bind();

      // analyze
      gatherAll(m_Context->parser->topList());

      // resolve refs between algorithms and blueprints
      for (const auto& bp : m_Blueprints) {
        Algorithm *alg = dynamic_cast<Algorithm*>(bp.second.raw());
        if (alg != nullptr) {
          alg->resolveInstancedBlueprintRefs(m_Blueprints);
        }
      }

      // done
      m_Context->unbind();

    } catch (LanguageError& le) {

      ReportError err(*m_Context->lpp, le.line(), dynamic_cast<antlr4::TokenStream*>(m_Context->parser->getInputStream()), le.token(), le.interval(), le.message());
      m_Context->unbind();
      throw Fatal("[SiliceCompiler] parser stopped");

    }

  }
}

// -------------------------------------------------

void SiliceCompiler::write(
  std::string to_export,
  const std::vector<std::string>& export_params)
{
  // check parser has been called
  if (m_Context.isNull()) {
    throw Fatal("[SiliceCompiler::write] please run parse before calling write");
  }
  std::ofstream out(m_Context->fresult);
  write(to_export, export_params, out);
}

// -------------------------------------------------

void SiliceCompiler::write(
  std::string                     to_export,
  const std::vector<std::string>& export_params,
  std::ostream&                   _out)
{
  // check parser has been called
  if (m_Context.isNull()) {
    throw Fatal("[SiliceCompiler::write] please run parse before calling write");
  }
  // generte output
  try {
    // bind context
    m_Context->bind();
    // write cmd line defines
    for (auto d : m_Context->defines) {
      std::cerr << "DEFINE " << d << '\n';
      auto eq = d.find('=');
      if (eq != std::string::npos) {
        _out << "`define " << d.substr(0, eq) << " " << d.substr(eq + 1) << nxl;
      }
    }
    // write framework (top) module
    _out << m_Context->framework_verilog;
    // write includes
    for (auto fname : m_AppendsInDeclOrder) {
      _out << Utils::fileToString(fname.c_str()) << nxl;
    }
    // write 'global' blueprints
    for (auto miordr : m_BlueprintsInDeclOrder) {
      Module *mod = dynamic_cast<Module*>(m_Blueprints.at(miordr).raw());
      if (mod != nullptr) {
        mod->writeModule(_out);
      }
      RISCVSynthesizer *rv = dynamic_cast<RISCVSynthesizer*>(m_Blueprints.at(miordr).raw());
      if (rv != nullptr) {
        rv->writeCompiled(_out);
      }
    }
    // which algorithm to export?
    if (to_export.empty()) {
      to_export = "main"; // export main by default
    }
    // find algorithm to export
    if (m_Blueprints.count(to_export) > 0) {
      Algorithm *alg = dynamic_cast<Algorithm*>(m_Blueprints[to_export].raw());
      if (alg == nullptr) {
        reportError(antlr4::misc::Interval::INVALID, -1, "could not find algorithm '%s'", to_export.c_str());
      } else {
        Algorithm::t_instantiation_context ictx;
        // ask for reports
        alg->enableReporting(m_Context->fresult);
        // add instantiation parameters to context
        for (auto p : export_params) {
          auto eq = p.find('=');
          if (eq != std::string::npos) {
            ictx.parameters[ p.substr(0, eq) ] = p.substr(eq + 1);
          }
        }
        // write algorithm (recurses from there)
        alg->writeAsModule("", _out, ictx);
      }
    } else {
      warn(Standard, antlr4::misc::Interval::INVALID, -1, "could not find algorithm '%s'", to_export.c_str());
    }
    // write formal unit tests
    for (auto const &[algname, bp] : m_Blueprints) {
      Algorithm *alg = dynamic_cast<Algorithm*>(bp.raw());
      if (alg != nullptr) {
        if (alg->isFormal()) {
          alg->enableReporting(m_Context->fresult);
          alg->writeAsModule("formal_" + algname + "$", _out);
        }
      }
    }
    // done
    m_Context->unbind();

  } catch (LanguageError& le) {

    ReportError err(*m_Context->lpp, le.line(), dynamic_cast<antlr4::TokenStream*>(m_Context->parser->getInputStream()), le.token(), le.interval(), le.message());
    m_Context->unbind();
    throw Fatal("[SiliceCompiler] writer stopped");

  }

}

// -------------------------------------------------

void SiliceCompiler::run(
  std::string fsource,
  std::string fresult,
  std::string fframework,
  std::string frameworks_dir,
  const std::vector<std::string>& defines,
  std::string to_export,
  const std::vector<std::string>& export_params)
{
  parse(fsource, fresult, fframework, frameworks_dir, defines);
  write(to_export, export_params);
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
  return extractCodeBetweenTokens(file, (int)first_tk->getTokenIndex(), (int)last_tk->getTokenIndex());
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
      codeline = extractCodeBetweenTokens(file, (int)interval.a, (int)interval.b);
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
