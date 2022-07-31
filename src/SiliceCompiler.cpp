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
  if (!m_BodyContext.isNull()) {
    for (auto path : m_BodyContext->lpp->searchPaths()) {
      tmp_fname = path + "/" + extractFileName(fname);
      if (LibSL::System::File::exists(tmp_fname.c_str())) {
        return tmp_fname;
      }
    }
    for (auto path : m_BodyContext->lpp->searchPaths()) {
      tmp_fname = path + "/" + fname;
      if (LibSL::System::File::exists(tmp_fname.c_str())) {
        return tmp_fname;
      }
    }
  }
  return fname;
}

// -------------------------------------------------

void SiliceCompiler::gatherBody(antlr4::tree::ParseTree* tree)
{
  if (tree == nullptr) {
    return;
  }

  auto root     = dynamic_cast<siliceParser::RootContext*>(tree);
  auto toplist  = dynamic_cast<siliceParser::TopListContext*>(tree);
  auto alg      = dynamic_cast<siliceParser::AlgorithmContext*>(tree);
  auto riscv    = dynamic_cast<siliceParser::RiscvContext *>(tree);
  auto unit     = dynamic_cast<siliceParser::UnitContext *>(tree);
  auto circuit  = dynamic_cast<siliceParser::CircuitryContext*>(tree);
  auto imprt    = dynamic_cast<siliceParser::ImportvContext*>(tree);
  auto app      = dynamic_cast<siliceParser::AppendvContext*>(tree);
  auto sub      = dynamic_cast<siliceParser::SubroutineContext*>(tree);
  auto group    = dynamic_cast<siliceParser::GroupContext*>(tree);
  auto intrface = dynamic_cast<siliceParser::IntrfaceContext *>(tree);
  auto bitfield = dynamic_cast<siliceParser::BitfieldContext*>(tree);

  if (toplist || root) {

    // keep going
    for (auto c : tree->children) {
      gatherBody(c);
    }

  } else if (alg || unit) {

    /// static unit
    // NOTE: the only way this can happen is if a unit is produced (written)
    //       from the Lua pre-processor and concatenated as a string.
    std::string name;
    siliceParser::InOutListContext* inout;
    if (alg) {
      name = alg->IDENTIFIER()->getText();
      inout = alg->inOutList();
    } else {
      name = unit->IDENTIFIER()->getText();
      inout = unit->inOutList();
    }
    std::cerr << "found static unit " << name << nxl;
    AutoPtr<Algorithm> unit(new Algorithm(m_Subroutines, m_Circuitries, m_Groups, m_Interfaces, m_BitFields));
    unit->gatherIOs(inout);
    gatherUnitBody(unit,tree);
    m_Blueprints.insert(std::make_pair(name, unit));
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

void SiliceCompiler::gatherUnitBody(AutoPtr<Algorithm> unit, antlr4::tree::ParseTree* tree)
{
  auto a = dynamic_cast<siliceParser::AlgorithmContext*>(tree);
  auto u = dynamic_cast<siliceParser::UnitContext *>(tree);
  sl_assert(a || u);
  /// algorithm or unit
  std::string name;
  bool hasHash;
  siliceParser::BpModifiersContext *mods = nullptr;
  if (a) {
    name    = a->IDENTIFIER()->getText();
    hasHash = a->HASH() != nullptr;
    mods    = a->bpModifiers();
  } else {
    name    = u->IDENTIFIER()->getText();
    hasHash = u->HASH() != nullptr;
    mods    = u->bpModifiers();
  }
  std::cerr << "parsing algorithm " << name << nxl;
  bool autorun = (name == "main"); // main always autoruns
  bool onehot = false;
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
        if (u) {
          throw Fatal("Unit cannot use the 'autorun' modifier, apply it to the internal algorithm block (line %d).",
            (int)m->sautorun()->getStart()->getLine());
        }
        autorun = true;
      }
      if (m->sonehot() != nullptr) {
        if (u) {
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
      if (m->sspecialize() != nullptr) {
        throw Fatal("The specialization modifier is only relevant during instantiation");
      }
    }
  }
  if (formalModes.empty()) {
    // default to a simple BMC if no mode is specified
    formalModes.push_back("bmc");
  }

  unit->init(
    name, hasHash, clock, reset, autorun, onehot, formalDepth, formalTimeout, formalModes
  );

  if (a) {
    unit->gatherBody(a->declAndInstrList());
  } else {
    unit->gatherBody(u->unitBlocks());
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

void SiliceCompiler::beginParsing(
  std::string fsource,
  std::string fresult,
  std::string fframework,
  std::string frameworks_dir,
  const std::vector<std::string>& defines,
  const Blueprint::t_instantiation_context& ictx)
{
  // check for double call
  if (!m_BodyContext.isNull()) {
    throw Fatal("[SiliceCompiler::parse] cannot parse a second time");
  }
  // determine frameworks dir if needed
  if (frameworks_dir.empty()) {
    frameworks_dir = std::string(LibSL::System::Application::executablePath()) + "../frameworks/";
  }
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

  // create the preprocessor
  AutoPtr<LuaPreProcessor> lpp(new LuaPreProcessor());
  lpp->enableFilesReport(fresult + ".files.log");
  std::string preprocessed = std::string(fresult) + ".lpp";
  Algorithm::setLuaPreProcessor(lpp.raw());

  // create parsing context for the design body
  m_BodyContext = AutoPtr<ParsingContext>(new ParsingContext(
    fresult, lpp, framework_verilog, defines));
  m_BodyContext->bind();

  // run preprocessor
  lpp->generateBody(fsource, c_DefaultLibraries, ictx, header, preprocessed);

  // parse the preprocessed source, if succeeded
  if (LibSL::System::File::exists(preprocessed.c_str())) {

    try {

      // analyze
      m_BodyContext->prepareParser(preprocessed);
      auto root = m_BodyContext->parser->root();
      m_BodyContext->setRoot(root);
      gatherBody(root);

    } catch (ReportError&) {

      throw Fatal("[SiliceCompiler] parser stopped");

    }
  }
}

// -------------------------------------------------

void SiliceCompiler::endParsing()
{
  // unbind context
  m_BodyContext->unbind();
  // done
  m_BodyContext = AutoPtr<ParsingContext>();
  Algorithm::setLuaPreProcessor(nullptr);
}

// -------------------------------------------------

t_parsed_unit SiliceCompiler::parseUnitIOs(std::string to_parse)
{
  t_parsed_unit parsed;

  parsed.parsed_unit = to_parse;
  std::string preprocessed_io = std::string(m_BodyContext->fresult) + "." + parsed.parsed_unit + ".io.lpp";

  // create parsing contexts
  parsed.ios_parser = AutoPtr<ParsingContext>(new ParsingContext(
    m_BodyContext->fresult, m_BodyContext->lpp,
    m_BodyContext->framework_verilog, m_BodyContext->defines));

  // unit
  auto alg    = AutoPtr<Algorithm>(new Algorithm(m_Subroutines, m_Circuitries, m_Groups, m_Interfaces, m_BitFields));
  parsed.unit = AutoPtr<Blueprint>(alg);

  { /// parse the ios
    // bind local context
    parsed.ios_parser->bind();
    // pre-process unit IOs (done first to gather intel on parameterized vs static ios
    m_BodyContext->lpp->generateUnitIOSource(parsed.parsed_unit, preprocessed_io);
    // gather the unit
    parsed.ios_parser->prepareParser(preprocessed_io);
    auto ios_root = parsed.ios_parser->parser->rootInOutList();
    parsed.ios_parser->setRoot(ios_root);
    // gather IOs
    alg->gatherIOs(ios_root->inOutList());
    // done
    parsed.ios_parser->unbind();
  }

  return parsed;
}

// -------------------------------------------------

void SiliceCompiler::parseUnitBody(t_parsed_unit& _parsed, const Blueprint::t_instantiation_context& ictx)
{
  std::string preprocessed = std::string(m_BodyContext->fresult) + "." + _parsed.parsed_unit + ".lpp";

  // create parsing context
  _parsed.body_parser = AutoPtr< ParsingContext>(new ParsingContext(
    m_BodyContext->fresult, m_BodyContext->lpp,
    m_BodyContext->framework_verilog, m_BodyContext->defines));

  /// parse the body
  // bind local context
  _parsed.body_parser->bind();
  // pre-process unit
  m_BodyContext->lpp->generateUnitSource(_parsed.parsed_unit, preprocessed, ictx);
  // gather the unit
  _parsed.body_parser->prepareParser(preprocessed);
  auto body_root = _parsed.body_parser->parser->rootUnit();
  _parsed.body_parser->setRoot(body_root);
  auto alg = AutoPtr<Algorithm>(_parsed.unit);
  if (body_root->unit()) {
    gatherUnitBody(alg, body_root->unit());
  } else {
    gatherUnitBody(alg, body_root->algorithm());
  }
  // done
  _parsed.body_parser->unbind();
}

// -------------------------------------------------

void SiliceCompiler::writeBody(std::ostream& _out, const Blueprint::t_instantiation_context& ictx)
{
  // check parser is active
  if (m_BodyContext.isNull()) {
    throw Fatal("[SiliceCompiler::write] body context not ready");
  }
  // write the body
  try {
    // bind context
    m_BodyContext->bind();
    // write cmd line defines
    for (auto d : m_BodyContext->defines) {
      auto eq = d.find('=');
      if (eq != std::string::npos) {
        _out << "`define " << d.substr(0, eq) << " " << d.substr(eq + 1) << nxl;
      }
    }
    // write framework (top) module
    _out << m_BodyContext->framework_verilog;
    // write includes
    for (auto fname : m_AppendsInDeclOrder) {
      _out << Utils::fileToString(fname.c_str()) << nxl;
    }

    // write static blueprints
    for (auto miordr : m_BlueprintsInDeclOrder) {
      Module *mod = dynamic_cast<Module*>(m_Blueprints.at(miordr).raw());
      // Verilog modules
      if (mod != nullptr) {
        mod->writeModule(_out);
      }
      // RISCV modules
      RISCVSynthesizer *rv = dynamic_cast<RISCVSynthesizer*>(m_Blueprints.at(miordr).raw());
      if (rv != nullptr) {
        rv->writeCompiled(_out);
      }
      // static units
      Algorithm *alg = dynamic_cast<Algorithm*>(m_Blueprints.at(miordr).raw());
      if (alg != nullptr) {
        t_parsed_unit pu;
        pu.body_parser = m_BodyContext;
        pu.unit        = m_Blueprints.at(miordr);
        writeUnit(pu, ictx, _out, true);
        writeUnit(pu, ictx, _out, false);
      }
    }
    // done
    m_BodyContext->unbind();

  } catch (ReportError&) {

    m_BodyContext->unbind();
    throw Fatal("[SiliceCompiler] writer stopped");

  }

}

// -------------------------------------------------

void SiliceCompiler::writeFormalTests(std::ostream& _out, const Blueprint::t_instantiation_context& ictx)
{
  // write formal unit tests
  for (auto name : m_BodyContext->lpp->formalUnits()) {
    // parse and write unit
    auto bp = parseUnitIOs(name);
    parseUnitBody(bp, ictx);
    bp.unit->setAsTopMost();
    Blueprint::t_instantiation_context local_ictx = ictx;
    local_ictx.instance_name = "formal_" + name + "$";
    // -> first pass
    writeUnit(bp, local_ictx, _out, true);
    // -> second pass
    writeUnit(bp, local_ictx, _out, false);
  }
}

// -------------------------------------------------

void SiliceCompiler::writeUnit(
  const t_parsed_unit&                                     parsed,
  const Blueprint::t_instantiation_context&                ictx,
  std::ostream&                                           _out,
  bool                                                     pass)
{
  // check parser is active
  if (m_BodyContext.isNull()) {
    throw Fatal("[SiliceCompiler::write] body context not ready");
  }

  try {

    // bind context
    parsed.body_parser->bind();
    // cast to algorithm
    Algorithm *alg = dynamic_cast<Algorithm*>(parsed.unit.raw());
    if (alg == nullptr) {
      reportError(t_source_loc(), "unit cannot be exported");
    } else {
      // ask for reports
      alg->enableReporting(m_BodyContext->fresult);
      // write algorithm (recurses from there)
      alg->writeAsModule(this, _out, ictx, pass);
    }
    // unbind context
    parsed.body_parser->unbind();

  } catch (ReportError&) {

    parsed.body_parser->unbind();
    throw Fatal("[SiliceCompiler] writer stopped");

  }

}

// -------------------------------------------------

AutoPtr<Blueprint> SiliceCompiler::isStaticBlueprint(std::string bpname)
{
  if (m_Blueprints.count(bpname) != 0) {
    return m_Blueprints.at(bpname);
  } else {
    return AutoPtr<Blueprint>();
  }
}

// -------------------------------------------------

void SiliceCompiler::run(
  std::string fsource,
  std::string fresult,
  std::string fframework,
  std::string frameworks_dir,
  const std::vector<std::string>& defines,
  const std::vector<std::string>& configs,
  std::string to_export,
  const std::vector<std::string>& export_params)
{
  try {

    // create top instantiation context
    Blueprint::t_instantiation_context ictx;
    for (auto p : export_params) {
      auto eq = p.find('=');
      if (eq != std::string::npos) {
        ictx.parameters[p.substr(0, eq)] = p.substr(eq + 1);
      }
    }
    // begin parsing
    beginParsing(fsource, fresult, fframework, frameworks_dir, defines, ictx);
    // apply command line config options
    for (auto cfg : configs) {
      auto eq = cfg.find('=');
      if (eq != std::string::npos) {
        CONFIG.keyValues()[cfg.substr(0, eq)] = cfg.substr(eq + 1);
      }
    }
    // display config
    CONFIG.print();
    // create output stream
    std::ofstream out(m_BodyContext->fresult);
    // write body
    writeBody(out, ictx);
    // write any formal test
    writeFormalTests(out, ictx);
    // which algorithm to export?
    if (to_export.empty()) {
      to_export = "main"; // export main by default
    }
    // parse and write top unit
    auto bp = parseUnitIOs(to_export);
    parseUnitBody(bp, ictx);
    bp.unit->setAsTopMost();
    ictx.instance_name = "";
    // -> first pass
    writeUnit(bp, ictx, out, true);
    // -> second pass
    writeUnit(bp, ictx, out, false);
    // stop parsing
    endParsing();

  } catch (ReportError&) {

    m_BodyContext->unbind();
    throw Fatal("[SiliceCompiler] writer stopped");

  }
}

// -------------------------------------------------
