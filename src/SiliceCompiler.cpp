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
#include "ChangeLog.h"
#include "VerilogTemplate.h"

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

bool g_Disable_CL0006 = false; // allows to force the use of outdates frameworks

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

void SiliceCompiler::gatherBody(antlr4::tree::ParseTree* tree, const Blueprint::t_instantiation_context& ictx)
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
      gatherBody(c, ictx);
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
    Blueprint::t_instantiation_context local_ictx = ictx;
    local_ictx.top_name = "M_" + name;
    gatherUnitBody(unit,tree, local_ictx);
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

void SiliceCompiler::gatherUnitBody(AutoPtr<Algorithm> unit, antlr4::tree::ParseTree* tree, const Blueprint::t_instantiation_context& ictx)
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
    unit->gatherBody(a->declAndInstrSeq(), ictx);
  } else {
    unit->gatherBody(u->unitBlocks(), ictx);
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
    frameworks_dir = std::string(FRAMEWORKS_DEFAULT_PATH);
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
      gatherBody(root, ictx);

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

t_parsed_circuitry SiliceCompiler::parseCircuitryIOs(std::string to_parse, const Blueprint::t_instantiation_context& ictx)
{
  t_parsed_circuitry parsed;

  parsed.parsed_circuitry = to_parse;
  std::string preprocessed_io = std::string(m_BodyContext->fresult) + "." + parsed.parsed_circuitry + ".io.lpp";

  // create parsing contexts
  parsed.ios_parser = AutoPtr<ParsingContext>(new ParsingContext(
    m_BodyContext->fresult, m_BodyContext->lpp,
    m_BodyContext->framework_verilog, m_BodyContext->defines));

  { /// parse the ios
    // bind local context
    parsed.ios_parser->bind();
    // pre-process unit IOs (done first to gather intel on parameterized vs static ios
    m_BodyContext->lpp->generateUnitIOSource(parsed.parsed_circuitry, preprocessed_io, ictx);
    // gather the unit
    parsed.ios_parser->prepareParser(preprocessed_io);
    auto ios_root = parsed.ios_parser->parser->rootIoList();
    parsed.ios_parser->setRoot(ios_root);
    parsed.ioList = ios_root->ioList();
    // done
    parsed.ios_parser->unbind();
  }

  return parsed;
}

// -------------------------------------------------

void               SiliceCompiler::parseCircuitryBody(t_parsed_circuitry& _parsed, const Blueprint::t_instantiation_context& ictx)
{
  std::string preprocessed = std::string(m_BodyContext->fresult) + "." + _parsed.parsed_circuitry + ".lpp";

  // create parsing context
  _parsed.body_parser = AutoPtr< ParsingContext>(new ParsingContext(
    m_BodyContext->fresult, m_BodyContext->lpp,
    m_BodyContext->framework_verilog, m_BodyContext->defines));

  /// parse the body
  // bind local context
  _parsed.body_parser->bind();
  // pre-process unit
  m_BodyContext->lpp->generateUnitSource(_parsed.parsed_circuitry, preprocessed, ictx);
  // gather the unit
  _parsed.body_parser->prepareParser(preprocessed);
  auto body_root = _parsed.body_parser->parser->rootCircuitry();
  _parsed.body_parser->setRoot(body_root);
  _parsed.circuitry = body_root->circuitry();
  // done
  _parsed.body_parser->unbind();
}

// -------------------------------------------------

t_parsed_unit SiliceCompiler::parseUnitIOs(std::string to_parse, const Blueprint::t_instantiation_context& ictx)
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
    m_BodyContext->lpp->generateUnitIOSource(parsed.parsed_unit, preprocessed_io, ictx);
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
    gatherUnitBody(alg, body_root->unit(), ictx);
  } else {
    gatherUnitBody(alg, body_root->algorithm(), ictx);
  }
  // done
  _parsed.body_parser->unbind();
}

// -------------------------------------------------

bool SiliceCompiler::addTopModulePort(
  std::string                      port,
  Utils::t_source_loc              srcloc,
  e_PortType                       type,
  std::map<std::string, e_PortType>& _used_pins
) {
  if (!m_BodyContext->lpp->isIOPortDefined(port)) {
    CHANGELOG.addPointOfInterest("CL0006", srcloc);
    if (g_Disable_CL0006) {
      warn(Deprecation, srcloc, "pin '%s' is not declared in framework\n             This may result in incorrect Verilog code.\n", port.c_str());
    } else {
      reportError(srcloc, "pin '%s' is not declared in framework\n         This may result in incorrect Verilog code.\n         Use --no-pin-check on command line to force.", port.c_str());
    }
    return false;
  } else {
    std::vector<std::string> pins;
    m_BodyContext->lpp->pinsUsedByIOPort(port, pins);
    if (pins.empty()) {
      reportError(srcloc, "pin group %s is empty", port.c_str());
    }
    for (auto p : pins) {
      if (!p.empty()) {
        if (_used_pins.count(p)) {
          reportError(srcloc, "pin %s is used multiple times", port.c_str());
        }
        _used_pins.insert(std::make_pair(p,type));
      }
    }
    return true;
  }
}

// -------------------------------------------------

std::string SiliceCompiler::verilogTopModuleSignature(const std::map<std::string, e_PortType>& used_pins)
{
  std::string sig;
  for (const auto& P : used_pins) {
    switch (P.second) 
    {
    case Input:  sig += "input  "; break;
    case Output: sig += "output "; break;
    case InOut:  sig += "inout  "; break;
    }
    int w = m_BodyContext->lpp->pinWidth(P.first);
    if (w > 1) {
      sig += "[" + std::to_string(w - 1) + ":0] ";
    }
    sig += P.first + ",\n";
  }
  return sig;
}

// -------------------------------------------------

std::string SiliceCompiler::verilogMainGlue(const std::map<std::string, e_PortType>& used_ports)
{
  std::string glue;
  for (const auto& P : used_ports) {
    switch (P.second) {
    case Input:  glue += ".in_"; break;
    case Output: glue += ".out_"; break;
    case InOut:  glue += ".inout_"; break;
    }
    std::vector<std::string> pins;
    m_BodyContext->lpp->pinsUsedByIOPort(P.first, pins);
    sl_assert(!pins.empty()); // checked before
    std::string bitvec = "{";
    for (int p = 0; p < pins.size(); ++p) {
      if (pins[p].empty()) {
        bitvec += "__unused_" + P.first + "_" + std::to_string(p) + ",";
      } else {
        bitvec += pins[p] + ",";
      }
    }
    bitvec  = bitvec.substr(0, bitvec.length() - 1); // remove last comma
    bitvec += "}";
    glue += P.first + "(" + bitvec + "),\n";
  }
  return glue;
}

// -------------------------------------------------

void SiliceCompiler::writeBody(const t_parsed_unit& parsed, std::ostream& _out, const Blueprint::t_instantiation_context& ictx)
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
    // build the top module signature, verify in/out/inout match pins, verify no pin is used twise
    std::map<std::string, e_PortType> used_ports;
    std::map<std::string, e_PortType> used_pins;
    for (auto in : parsed.unit->inputs()) {
      if (addTopModulePort(in.name, in.srcloc, Input, used_pins)) {
        used_ports.insert(std::make_pair(in.name, Input));
      }
    }
    for (auto ou : parsed.unit->outputs()) {
      if (addTopModulePort(ou.name, ou.srcloc, Output, used_pins)) {
        used_ports.insert(std::make_pair(ou.name, Output));
      }
    }
    for (auto io : parsed.unit->inOuts()) {
      if (addTopModulePort(io.name, io.srcloc, InOut, used_pins)) {
        used_ports.insert(std::make_pair(io.name, InOut));
      }
    }
    // check all ports are found, produce unused wires declarations
    std::string wire_decl;
    for (const auto& P : used_ports) {
      std::vector<std::string> pins;
      m_BodyContext->lpp->pinsUsedByIOPort(P.first, pins);
      sl_assert(!pins.empty()); // checked before
      for (int p = 0; p < pins.size(); ++p) {
        if (pins[p].empty()) {
          wire_decl += "wire __unused_" + P.first + "_" + std::to_string(p) + ";\n";
        }
      }
    }
    // update framework
    VerilogTemplate frmwrk;
    std::unordered_map<std::string, std::string> replacements;
    replacements["TOP_SIGNATURE"] = verilogTopModuleSignature(used_pins); // top module signature
    replacements["MAIN_GLUE"]     = verilogMainGlue(used_ports); // main module glue
    replacements["WIRE_DECL"]     = wire_decl; // main module wire declarations
    frmwrk.fromString(m_BodyContext->framework_verilog, replacements);
    // write framework (top) module    
    _out << frmwrk.code();
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
        Blueprint::t_instantiation_context local_ictx = ictx;
        local_ictx.top_name = "M_" + alg->name();
        writeUnit(pu, local_ictx, _out, true);
        writeUnit(pu, local_ictx, _out, false);
      }
    }
    // done
    m_BodyContext->unbind();

  } catch (ReportError& e) {

    m_BodyContext->unbind();
    throw e;

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
      alg->writeAsModule(_out, ictx, pass);
    }
    // unbind context
    parsed.body_parser->unbind();

  } catch (ReportError&) {

    parsed.body_parser->unbind();
    throw Fatal("[SiliceCompiler] writer stopped");

  }

}

// -------------------------------------------------

/// \brief write formal units in the output stream
void SiliceCompiler::writeFormalTests(std::ostream& _out, const Blueprint::t_instantiation_context& ictx)
{
  if (m_BodyContext.isNull()) {
    throw Fatal("[SiliceCompiler::writeFormalTests] body context not ready");
  }
  // write formal unit tests
  for (auto name : m_BodyContext->lpp->formalUnits()) {
    Blueprint::t_instantiation_context local_ictx = ictx;
    local_ictx.top_name = "formal_" + name + "$"; // FIXME: inelegant
    // parse and write unit
    auto bp = parseUnitIOs(name, local_ictx);
    parseUnitBody(bp, local_ictx);
    bp.unit->setAsTopMost();
    // -> first pass
    writeUnit(bp, local_ictx, _out, true);
    // -> second pass
    writeUnit(bp, local_ictx, _out, false);
  }
}

// -------------------------------------------------

/// \brief writes a static unit in the output stream
///        NOTE: used by the python framework
void SiliceCompiler::writeStaticUnit(
  AutoPtr<Blueprint>                        bp,
  const Blueprint::t_instantiation_context& ictx,
  std::ostream&                            _out,
  bool                                      first_pass)
{
  t_parsed_unit pu;
  pu.body_parser = m_BodyContext;
  pu.unit        = bp;
  writeUnit(pu, ictx, _out, first_pass);
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

void SiliceCompiler::getUnitNames(std::unordered_set<std::string>& _units)
{
  for (auto b : m_Blueprints) {
    _units.insert(b.first);
  }
  if (!m_BodyContext.isNull()) {
    for (auto name : m_BodyContext->lpp->units()) {
      _units.insert(name);
    }
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
    ictx.compiler = this;
    for (auto p : export_params) {
      auto eq = p.find('=');
      if (eq != std::string::npos) {
        ictx.autos [p.substr(0, eq)] = p.substr(eq + 1); // NOTE TODO: we add to both without distinction but that might have
        ictx.params[p.substr(0, eq)] = p.substr(eq + 1); // side-effects compared to a std instantiation since autos are for types only ...
      }
    }
    // create report files, delete them if existing
    {
      std::ofstream freport_v(fresult + ".vio.log");
      std::ofstream freport_a(fresult + ".alg.log");
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
    // which algorithm to export?
    if (to_export.empty()) {
      to_export = "main"; // export main by default
    }
    ictx.top_name = "M_" + to_export;
    // parse top unit
    auto bp = parseUnitIOs(to_export, ictx);
    parseUnitBody(bp, ictx);
    bp.unit->setAsTopMost();
    // write body
    writeBody(bp, out, ictx);
    // write top unit
    // -> first pass
    writeUnit(bp, ictx, out, true);
    // -> second pass
    writeUnit(bp, ictx, out, false);
    // write any formal test
    writeFormalTests(out, ictx);
    // stop parsing
    endParsing();

    // change log report
    CHANGELOG.printReport(std::cout);

  } catch (ReportError&) {

    // change log report
    CHANGELOG.printReport(std::cerr);

    m_BodyContext->unbind();
    throw Fatal("[SiliceCompiler] writer stopped");

  }
}

// -------------------------------------------------
