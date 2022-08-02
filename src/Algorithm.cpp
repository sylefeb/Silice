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

#include "Algorithm.h"
#include "Module.h"
#include "Config.h"
#include "VerilogTemplate.h"
#include "ExpressionLinter.h"
#include "LuaPreProcessor.h"
#include "Utils.h"
#include "SiliceCompiler.h"

#include <cctype>

using namespace std;
using namespace antlr4;
using namespace Silice;
using namespace Silice::Utils;

#define SUB_ENTRY_BLOCK "__sub_"

LuaPreProcessor *Algorithm::s_LuaPreProcessor = nullptr;

// -------------------------------------------------

const std::vector<std::string> c_InOutmembers = {
  {"i"},{"o"},{"oenable"} // NOTE: first has to be the input
};

// -------------------------------------------------

bool is_number(const std::string &s)
{
  return !s.empty() && std::all_of(s.begin(), s.end(), ::isdigit);
}

// -------------------------------------------------

typedef struct {
  bool        is_input;
  bool        is_addr;
  std::string name;
} t_mem_member;

const std::vector<t_mem_member> c_BRAMmembers = {
  {true, false,"wenable"},
  {false,false,"rdata"},
  {true, false,"wdata"},
  {true, true, "addr"}
};

const std::vector<t_mem_member> c_BROMmembers = {
  {false,false,"rdata"},
  {true, true, "addr"}
};

const std::vector<t_mem_member> c_DualPortBRAMmembers = {
  {true, false,"wenable0"},
  {false,false,"rdata0"},
  {true, false,"wdata0"},
  {true, true, "addr0"},
  {true, false,"wenable1"},
  {false,false,"rdata1"},
  {true, false,"wdata1"},
  {true, true, "addr1"},
};

const std::vector<t_mem_member> c_SimpleDualPortBRAMmembers = {
  {false,false,"rdata0"},
  {true, true, "addr0"},
  {true, false,"wenable1"},
  {true, false,"wdata1"},
  {true, true, "addr1"},
};

// -------------------------------------------------

void Algorithm::checkBlueprintsBindings(const t_instantiation_context &ictx) const
{
  for (auto& bp : m_InstancedBlueprints) {
    set<string> inbound;
    for (const auto& b : bp.second.bindings) {
      // check left side
      bool is_input  = bp.second.blueprint->isInput (b.left);
      bool is_output = bp.second.blueprint->isOutput(b.left);
      bool is_inout  = bp.second.blueprint->isInOut (b.left);
      if (!is_input && !is_output && !is_inout) {
        if (m_VIOGroups.count(bindingRightIdentifier(b)) > 0) {
          reportError(b.srcloc, "instance '%s', binding '%s': use <:> to bind groups and interfaces",
            bp.first.c_str(), b.left.c_str());
        } else {
          reportError(b.srcloc, "instance '%s', binding '%s': wrong binding point (neither input nor output)",
            bp.first.c_str(), b.left.c_str());
        }
      }
      if ((b.dir == e_Left || b.dir == e_LeftQ) && !is_input) { // input
        reportError(b.srcloc, "instance '%s', binding output '%s': wrong binding direction",
          bp.first.c_str(), b.left.c_str());
      }
      if (b.dir == e_Right && !is_output) { // output
        reportError(b.srcloc, "instance '%s', binding input '%s': wrong binding direction",
          bp.first.c_str(), b.left.c_str());
      }
      if (b.dir == e_BiDir && !is_inout) { // inout
        reportError(b.srcloc, "instance '%s', binding inout '%s': wrong binding direction",
          bp.first.c_str(), b.left.c_str());
      }
      // check right side
      std::string br = bindingRightIdentifier(b);
      // check existence
      if (!isInputOrOutput(br) && !isInOut(br)
        && m_VarNames.count(br) == 0
        && br != m_Clock && br != ALG_CLOCK
        && br != m_Reset && br != ALG_RESET) {
        reportError(b.srcloc, "instance '%s', binding '%s' to '%s': wrong binding point",
          bp.first.c_str(), br.c_str(), b.left.c_str());
      }
      if (b.dir == e_Left || b.dir == e_LeftQ) {
        // track inbound
        inbound.insert(br);
      }
      // check combinational output consistency
      // NOTE only valid for blueprints providing output combinational informations
      if (bp.second.blueprint->hasOutputCombinationalInfo()) {
        if (is_output && isOutput(br)) {
          sl_assert(b.dir == e_Right);
          // instance output is bound to an algorithm output
          bool instr_comb = bp.second.blueprint->outputs().at(bp.second.blueprint->outputNames().at(b.left)).combinational;
          if (m_Outputs.at(m_OutputNames.at(br)).combinational ^ instr_comb) {
            reportError(b.srcloc, "instance '%s', binding instance output '%s' to algorithm output '%s'\n"
              "using a mix of output! and output. Consider adjusting the parent algorithm output to '%s'.",
              bp.first.c_str(), b.left.c_str(), br.c_str(), instr_comb ? "output!" : "output");
          }
        }
      }
      // lint bindings
      {
        ExpressionLinter linter(this, ictx);
        linter.lintBinding(
          sprint("instance '%s', binding '%s' to '%s'", bp.first.c_str(), br.c_str(), b.left.c_str()),
          b.dir, b.srcloc,
          get<0>(bp.second.blueprint->determineVIOTypeWidthAndTableSize(translateVIOName(b.left, nullptr), b.srcloc)),
          get<0>(determineVIOTypeWidthAndTableSize(translateVIOName(br, nullptr), b.srcloc))
        );
      }
    }
    // check no binding appears with both directions (excl. inout)
    for (const auto &b : bp.second.bindings) {
      std::string br = bindingRightIdentifier(b);
      if (b.dir == e_Right) {
        if (inbound.count(br) > 0) {
          reportError(b.srcloc, "binding appears both as input and output on the same instance, instance '%s', bound vio '%s'",
            bp.first.c_str(), br.c_str());
        }
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::autobindInstancedBlueprint(t_instanced_nfo& _bp)
{
  // -> set of already defined bindings
  set<std::string> defined;
  for (auto b : _bp.bindings) {
    defined.insert(b.left);
  }
  // -> for each algorithm inputs
  for (auto io : _bp.blueprint->inputs()) {
    if (defined.find(io.name) == defined.end()) {
      // not bound, check if host algorithm has an input with same name
      if (m_InputNames.find(io.name) != m_InputNames.end()) {
        // yes: autobind
        t_binding_nfo bnfo;
        bnfo.srcloc = _bp.srcloc;
        bnfo.left   = io.name;
        bnfo.right  = io.name;
        bnfo.dir    = e_Left;
        _bp.bindings.push_back(bnfo);
      } else // check if algorithm has a var with same name
        if (m_VarNames.find(io.name) != m_VarNames.end()) {
          // yes: autobind
          t_binding_nfo bnfo;
          bnfo.srcloc = _bp.srcloc;
          bnfo.left   = io.name;
          bnfo.right  = io.name;
          bnfo.dir    = e_Left;
          _bp.bindings.push_back(bnfo);
        }
    }
  }
  // -> internals (clock and reset)
  std::vector<std::string> internals;
  internals.push_back(ALG_CLOCK);
  internals.push_back(ALG_RESET);
  for (auto io : internals) {
    if (defined.find(io) == defined.end()) {
      // not bound, check if algorithm has an input with same name
      if (_bp.blueprint->inputNames().find(io) != _bp.blueprint->inputNames().end()) {
        // yes: autobind
        t_binding_nfo bnfo;
        bnfo.srcloc = _bp.srcloc;
        bnfo.left   = io;
        bnfo.right  = io;
        bnfo.dir    = e_Left;
        _bp.bindings.push_back(bnfo);
      }
    }
  }
  // -> for each algorithm output
  for (auto io : _bp.blueprint->outputs()) {
    if (defined.find(io.name) == defined.end()) {
      // not bound, check if host algorithm has an output with same name
      if (m_OutputNames.find(io.name) != m_OutputNames.end()) {
        // yes: autobind
        t_binding_nfo bnfo;
        bnfo.srcloc = _bp.srcloc;
        bnfo.left   = io.name;
        bnfo.right  = io.name;
        bnfo.dir    = e_Right;
        _bp.bindings.push_back(bnfo);
      } else // check if algorithm has a var with same name
        if (m_VarNames.find(io.name) != m_VarNames.end()) {
          // yes: autobind
          t_binding_nfo bnfo;
          bnfo.srcloc = _bp.srcloc;
          bnfo.left   = io.name;
          bnfo.right  = io.name;
          bnfo.dir    = e_Right;
          _bp.bindings.push_back(bnfo);
        }
    }
  }
  // -> for each algorithm inout
  for (auto io : _bp.blueprint->inOuts()) {
    if (defined.find(io.name) == defined.end()) {
      // not bound
      // check if algorithm has an inout with same name
      if (m_InOutNames.find(io.name) != m_InOutNames.end()) {
        // yes: autobind
        t_binding_nfo bnfo;
        bnfo.srcloc = _bp.srcloc;
        bnfo.left   = io.name;
        bnfo.right  = io.name;
        bnfo.dir    = e_BiDir;
        _bp.bindings.push_back(bnfo);
      }
      // check if algorithm has a var with same name
      else {
        if (m_VarNames.find(io.name) != m_VarNames.end()) {
          // yes: autobind
          t_binding_nfo bnfo;
          bnfo.srcloc = _bp.srcloc;
          bnfo.left   = io.name;
          bnfo.right  = io.name;
          bnfo.dir    = e_BiDir;
          _bp.bindings.push_back(bnfo);
        }
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::resolveInstancedBlueprintBindingDirections(t_instanced_nfo& _bp)
{
  std::vector<t_binding_nfo> cleanedup_bindings;
  for (auto& b : _bp.bindings) {
    if (b.dir == e_Auto || b.dir == e_AutoQ) {
      // input?
      if (_bp.blueprint->isInput(b.left)) {
        b.dir = (b.dir == e_Auto) ? e_Left : e_LeftQ;
      }
      // output?
      else if (_bp.blueprint->isOutput(b.left)) {
        b.dir = e_Right;
      }
      // inout?
      else if (_bp.blueprint->isInOut(b.left)) {
        b.dir = e_BiDir;
      } else {

        // group member is not used by the algorithm, we allow this for flexibility,
        // in particular in conjunction with interfaces (partial binding)
        continue;

        //reportError(nullptr, b.line, "cannot determine binding direction for '%s <:> %s', binding to algorithm instance '%s'",
        //  b.left.c_str(), bindingRightIdentifier(b).c_str(), _alg.instance_name.c_str());
      }
    }
    cleanedup_bindings.push_back(b);
  }
  _bp.bindings = cleanedup_bindings;
}

// -------------------------------------------------

Algorithm::~Algorithm()
{
  // delete all blocks
  for (auto B : m_Blocks) {
    delete (B);
  }
  m_Blocks.clear();
  // delete all subroutines
  for (auto S : m_Subroutines) {
    delete (S.second);
  }
  m_Subroutines.clear();
  // delete all pipelines
  for (auto p : m_Pipelines) {
    for (auto s : p->stages) {
      delete (s);
    }
    delete (p);
  }
  m_Pipelines.clear();
}

// -------------------------------------------------

bool Algorithm::isVIO(std::string var) const
{
  return isInput(var) || isOutput(var) || isInOut(var) || m_VarNames.count(var) > 0;
}

// -------------------------------------------------

bool Algorithm::isGroupVIO(std::string var) const
{
  return m_VIOGroups.find(var) != m_VIOGroups.end();
}

// -------------------------------------------------

template<class T_Block>
Algorithm::t_combinational_block *Algorithm::addBlock(
  std::string name,
  const t_combinational_block* parent,
  const t_combinational_block_context *bctx,
  const t_source_loc& srcloc)
{
  auto B = m_State2Block.find(name);
  if (B != m_State2Block.end()) {
    reportError(srcloc, "state name '%s' already defined", name.c_str());
  }
  size_t next_id = m_Blocks.size();
  m_Blocks.emplace_back(new T_Block());
  m_Blocks.back()->block_name           = name;
  m_Blocks.back()->id                   = next_id;
  m_Blocks.back()->srcloc               = srcloc;
  m_Blocks.back()->end_action           = nullptr;
  m_Blocks.back()->context.parent_scope = parent;
  if (bctx) {
    m_Blocks.back()->context.subroutine   = bctx->subroutine;
    m_Blocks.back()->context.pipeline     = bctx->pipeline;
    m_Blocks.back()->context.vio_rewrites = bctx->vio_rewrites;
  } else if (parent) {
    m_Blocks.back()->context.subroutine   = parent->context.subroutine;
    m_Blocks.back()->context.pipeline     = parent->context.pipeline;
    m_Blocks.back()->context.vio_rewrites = parent->context.vio_rewrites;
  }
  m_Id2Block[next_id] = m_Blocks.back();
  m_State2Block[name] = m_Blocks.back();
  return m_Blocks.back();
}

// -------------------------------------------------

std::string Algorithm::rewriteConstant(std::string cst) const
{
  int width;
  std::string value;
  char base;
  bool negative;
  splitConstant(cst, width, base, value, negative);
  return (negative ? "-" : "") + std::to_string(width) + "'" + base + value;
}

// -------------------------------------------------

int Algorithm::bitfieldWidth(siliceParser::BitfieldContext* field) const
{
  int tot_width = 0;
  for (auto v : field->varList()->var()) {
    t_type_nfo tn;
    if (v->declarationVar()->type()->TYPE() == nullptr) {
      reportError(sourceloc(v->declarationVar()), "a bitfield cannot contain a 'sameas' definition");
    }
    splitType(v->declarationVar()->type()->TYPE()->getText(), tn);
    tot_width += tn.width;
  }
  return tot_width;
}

// -------------------------------------------------

std::pair<t_type_nfo, int> Algorithm::bitfieldMemberTypeAndOffset(siliceParser::BitfieldContext* field, std::string member) const
{
  int offset = 0;
  sl_assert(!field->varList()->var().empty());
  ForRangeReverse(i, (int)field->varList()->var().size() - 1, 0) {
    auto v = field->varList()->var()[i];
    t_type_nfo tn;
    if (v->declarationVar()->type()->TYPE() == nullptr) {
      reportError(sourceloc(v->declarationVar()), "a bitfield cannot contain a 'sameas' definition");
    }
    splitType(v->declarationVar()->type()->TYPE()->getText(), tn);
    if (member == v->declarationVar()->IDENTIFIER()->getText()) {
      return make_pair(tn, offset);
    }
    offset += tn.width;
  }
  return make_pair(t_type_nfo(),-1);
}

// -------------------------------------------------

std::string Algorithm::gatherBitfieldValue(siliceParser::InitBitfieldContext* ifield)
{
  // find field definition
  auto F = m_KnownBitFields.find(ifield->field->getText());
  if (F == m_KnownBitFields.end()) {
    reportError(sourceloc(ifield), "unknown bitfield '%s'", ifield->field->getText().c_str());
  }
  // gather const values for each named entry
  unordered_map<string, pair<bool,string> > named_values;
  for (auto ne : ifield->namedValue()) {
    verifyMemberBitfield(ne->name->getText(), F->second);
    named_values[ne->name->getText()] = make_pair(
      (ne->constValue()->CONSTANT() != nullptr), // true if sized constant
      gatherConstValue(ne->constValue()));
  }
  // verify we have all required fields, and only them
  if (named_values.size() != F->second->varList()->var().size()) {
    reportError(sourceloc(ifield), "incorrect number of names values in field initialization", ifield->field->getText().c_str());
  }
  // concatenate and rewrite as a single number with proper width
  int fwidth = bitfieldWidth(F->second);
  string concat = "{";
  int n = (int)F->second->varList()->var().size();
  for (auto v : F->second->varList()->var()) {
    auto ne = named_values.at(v->declarationVar()->IDENTIFIER()->getText());
    t_type_nfo tn;
    if (v->declarationVar()->type()->TYPE() == nullptr) {
      reportError(sourceloc(v->declarationVar()), "a bitfield cannot contain a 'sameas' definition");
    }
    splitType(v->declarationVar()->type()->TYPE()->getText(), tn);
    if (ne.first) {
      concat = concat + ne.second;
    } else {
      concat = concat + to_string(tn.width) + "'d" + ne.second;
    }
    if (--n > 0) {
      concat = concat + ",";
    }
  }
  concat = concat + "}";
  return concat;
}

// -------------------------------------------------

std::string Algorithm::gatherValue(siliceParser::ValueContext* ival)
{
  if (ival->constValue() != nullptr) {
    return gatherConstValue(ival->constValue());
  } else {
    sl_assert(ival->initBitfield() != nullptr);
    return gatherBitfieldValue(ival->initBitfield());
  }
}

// -------------------------------------------------

void Algorithm::insertVar(const t_var_nfo &_var, t_combinational_block *_current)
{
  t_subroutine_nfo *sub = nullptr;
  if (_current) {
    sub = _current->context.subroutine;
  }
  m_Vars    .emplace_back(_var);
  m_VarNames.insert(std::make_pair(_var.name, (int)m_Vars.size() - 1));
  if (sub != nullptr) {
    sub->varnames.insert(std::make_pair(_var.name, (int)m_Vars.size() - 1));
  }
  if (!_var.do_not_initialize && !_var.init_at_startup) {
    // add to block initialization set
    _current->initialized_vars.insert(make_pair(_var.name, (int)m_Vars.size() - 1));
    _current->no_skip = true; // mark block as cannot skip to honor var initializations
  }
  // add to block declared vios
  _current->declared_vios.insert(_var.name);
}

// -------------------------------------------------

void Algorithm::addVar(t_var_nfo& _var, t_combinational_block *_current, const Utils::t_source_loc& srcloc)
{
  t_subroutine_nfo *sub = nullptr;
  if (_current) {
    sub = _current->context.subroutine;
  }
  // subroutine renaming?
  if (sub != nullptr) {
    std::string base_name = _var.name;
    _var.name = subroutineVIOName(base_name, sub);
    _var.name = blockVIOName(_var.name, _current);
    sub->vios.insert(std::make_pair(base_name, _var.name));
    sub->vars.push_back(base_name);
    sub->allowed_reads .insert(_var.name);
    sub->allowed_writes.insert(_var.name);
  } else {
    // block renaming
    std::string base_name = _var.name;
    _var.name = blockVIOName(base_name,_current);
    _current->context.vio_rewrites[base_name] = _var.name;
  }
  _var.srcloc = srcloc;
  // check for duplicates
  if (!isIdentifierAvailable(_var.name)) {
    reportError(srcloc, "variable '%s': this name is already used by a prior declaration", _var.name.c_str());
  }
  // ok!
  insertVar(_var, _current);
}

// -------------------------------------------------

void Algorithm::gatherDeclarationWire(siliceParser::DeclarationWireContext* wire, t_combinational_block *_current)
{
  t_var_nfo nfo;
  // checks
  if (wire->alwaysAssigned()->IDENTIFIER() == nullptr) {
    reportError(sourceloc(wire), "improper wire declaration, has to be an identifier");
  }
  nfo.name = wire->alwaysAssigned()->IDENTIFIER()->getText();
  nfo.table_size = 0;
  nfo.do_not_initialize = true;
  nfo.usage = e_Wire;
  // get type
  std::string is_group;
  gatherTypeNfo(wire->type(), nfo.type_nfo, _current, is_group);
  if (!is_group.empty()) {
    reportError(sourceloc(wire), "'sameas' wire declaration cannot be refering to a group or interface");
  }
  // add var
  addVar(nfo, _current, sourceloc(wire, wire->alwaysAssigned()->IDENTIFIER()->getSourceInterval()));
  // insert wire assignment
  m_WireAssignmentNames.insert( make_pair(nfo.name, (int)m_WireAssignments.size()) );
  m_WireAssignments    .push_back( make_pair(nfo.name, t_instr_nfo(wire->alwaysAssigned(), _current, -1)) );
}

// -------------------------------------------------

void Algorithm::gatherVarNfo(siliceParser::DeclarationVarContext *decl, t_var_nfo &_nfo, bool default_no_init, const t_combinational_block *_current, std::string &_is_group)
{
  _nfo.name = decl->IDENTIFIER()->getText();
  _nfo.table_size = 0;
  // get type
  gatherTypeNfo(decl->type(), _nfo.type_nfo, _current, _is_group);
  if (!_is_group.empty()) {
    return;
  } else {
    // init values
    if (decl->declarationVarInitSet()) {
      if (decl->declarationVarInitSet()->value() != nullptr) {
        _nfo.init_values.push_back("0");
        _nfo.init_values[0] = gatherValue(decl->declarationVarInitSet()->value());
      } else {
        if (decl->declarationVarInitSet()->UNINITIALIZED() != nullptr || default_no_init) {
          _nfo.do_not_initialize = true;
        } else {
          reportError(sourceloc(decl), "variable has no initializer, use '= uninitialized' if you really don't want to initialize it.");
        }
      }
      _nfo.init_at_startup = false;
    } else if (decl->declarationVarInitCstr()) {
      if (decl->declarationVarInitCstr()->value() != nullptr) {
        _nfo.init_values.push_back("0");
        _nfo.init_values[0] = gatherValue(decl->declarationVarInitCstr()->value());
      } else {
        if (decl->declarationVarInitCstr()->UNINITIALIZED() != nullptr || default_no_init) {
          _nfo.do_not_initialize = true;
        } else {
          reportError(sourceloc(decl), "variable has no initializer, use '= uninitialized' if you really don't want to initialize it.");
        }
      }
      _nfo.init_at_startup = true;
    } else {
      if (!default_no_init) {
        reportError(sourceloc(decl), "variable has no initializer, use '= uninitialized' if you really don't want to initialize it.");
      }
      _nfo.do_not_initialize = true;
    }
    if (decl->ATTRIBS() != nullptr) {
      _nfo.attribs = decl->ATTRIBS()->getText();
    }
  }
}

// -------------------------------------------------

void Algorithm::gatherDeclarationVar(siliceParser::DeclarationVarContext* decl, t_combinational_block *_current)
{
  // gather variable
  t_var_nfo var;
  std::string is_group;
  gatherVarNfo(decl, var, false, _current, is_group);
  // check if var is a group
  if (!is_group.empty()) {
    if (decl->declarationVarInitSet() != nullptr || decl->declarationVarInitCstr() != nullptr || decl->ATTRIBS() != nullptr) {
      reportError(sourceloc(decl), "variable is declared as 'sameas' a group or interface, it cannot have initializers.");
    }
    // find group (should be here, according to gatherTypeNfo)
    auto G = m_VIOGroups.find(is_group);
    sl_assert(G != m_VIOGroups.end());
    // now, insert as group, where each member is parameterized by the corresponding interface member
    m_VIOGroups.insert(make_pair(var.name, G->second));
    // get member list from interface
    for (auto mbr : getGroupMembers(G->second)) {
      // search parameterizing var
      std::string typed_by = is_group + "_" + mbr;
      typed_by = findSameAsRoot(typed_by, &_current->context);
      // add var
      t_var_nfo vnfo;
      vnfo.name = var.name + "_" + mbr;
      vnfo.type_nfo.base_type = Parameterized;
      vnfo.type_nfo.same_as = typed_by;
      vnfo.type_nfo.width = 0;
      vnfo.table_size = 0;
      vnfo.do_not_initialize = false;
      // add it
      addVar(vnfo, _current, sourceloc(decl, decl->IDENTIFIER()->getSourceInterval()));
    }
  } else {
    addVar(var, _current, sourceloc(decl, decl->IDENTIFIER()->getSourceInterval()));
  }
}

// -------------------------------------------------

void Algorithm::gatherTableNfo(siliceParser::DeclarationTableContext *decl, t_var_nfo &_nfo, t_combinational_block *_current)
{
  _nfo.name = decl->IDENTIFIER()->getText();
  _nfo.table_size = 0;
  // get type
  std::string is_group;
  gatherTypeNfo(decl->type(), _nfo.type_nfo, _current, is_group);
  if (!is_group.empty()) {
    reportError(sourceloc(decl->type()), "'sameas' in table declarations are not yet supported");
  }
  // init values
  if (decl->NUMBER() != nullptr) {
    _nfo.table_size = atoi(decl->NUMBER()->getText().c_str());
    if (_nfo.table_size <= 0) {
      reportError(sourceloc(decl->NUMBER()), "table has zero or negative size");
    }
  } else {
    _nfo.table_size = 0; // autosize from init
  }
  readInitList(decl, _nfo);
}

// -------------------------------------------------

void Algorithm::gatherDeclarationTable(siliceParser::DeclarationTableContext *decl, t_combinational_block *_current)
{
  t_var_nfo var;
  gatherTableNfo(decl, var, _current);
  addVar(var, _current, sourceloc(decl, decl->IDENTIFIER()->getSourceInterval()));
}

// -------------------------------------------------

void Algorithm::gatherInitList(siliceParser::InitListContext* ilist, std::vector<std::string>& _values_str)
{
  for (auto i : ilist->value()) {
    _values_str.push_back(gatherValue(i));
  }
}

// -------------------------------------------------

void Algorithm::gatherInitListFromFile(int width, siliceParser::InitListContext *ilist, std::vector<std::string> &_values_str)
{
  sl_assert(ilist->file() != nullptr);
  // check variable width
  if (width != 8 && width != 16 && width != 32) {
    reportError(sourceloc(ilist->file()), "can only read int8/uint8, int16/uint16 and int32/uint32 from files");
  }
  // get filename
  std::string fname = ilist->file()->STRING()->getText();
  fname = fname.substr(1, fname.length() - 2); // remove '"' and '"'
  fname = s_LuaPreProcessor->findFile(fname);
  if (!LibSL::System::File::exists(fname.c_str())) {
    reportError(sourceloc(ilist->file()), "file '%s' not found", fname.c_str());
  }
  FILE *f = fopen(fname.c_str(),"rb");
  std::cerr << "- reading " << width << " bits data from file " << fname << '.' << nxl;
  if (width == 8) {
    uchar v;
    while (fread(&v, 1, 1, f)) {
      _values_str.push_back(sprint("8'h%02X",v));
    }
  } else if (width == 16) {
    ushort v;
    while (fread(&v, sizeof(ushort), 1, f)) {
      _values_str.push_back(sprint("16'h%04X", v));
    }
  } else if (width == 32) {
    uint v;
    while (fread(&v, sizeof(uint), 1, f)) {
      _values_str.push_back(sprint("32'h%08X", v));
    }
  } else {
    sl_assert(false);
  }
  std::cerr << Console::white << "- read " << _values_str.size() << " words." << nxl;
  fclose(f);
}

// -------------------------------------------------

template<typename D, typename T>
void Algorithm::readInitList(D* decl,T& var)
{
  // read init list
  std::vector<std::string> values_str;
  if (decl->initList() != nullptr) {
    if (decl->initList()->file() == nullptr) {
      gatherInitList(decl->initList(), values_str);
    } else {
      gatherInitListFromFile(var.type_nfo.width, decl->initList(), values_str);
    }
  } else if (decl->STRING() != nullptr) {
    std::string initstr = decl->STRING()->getText();
    initstr = initstr.substr(1, initstr.length() - 2); // remove '"' and '"'
    values_str.resize(initstr.length() + 1/*null terminated*/);
    ForIndex(i, (int)initstr.length()) {
      values_str[i] = std::to_string((int)(initstr[i]));
    }
    values_str.back() = "0"; // null terminated
  } else {
    if (var.table_size == 0) {
      reportError(sourceloc(decl), "cannot deduce table size: no size and no initialization given");
    }
    if (decl->UNINITIALIZED() != nullptr) {
      var.do_not_initialize = true;
    } else {
      reportError(sourceloc(decl), "table has no initializer, use '= uninitialized' if you really don't want to initialize it.");
    }
  }
  var.init_values.clear();
  if (!var.do_not_initialize) {
    if (var.table_size == 0) {
      // autosize
      var.table_size = (int)values_str.size();
    } else if (values_str.size() != var.table_size) {
      // pad?
      if (values_str.size() < var.table_size) {
        if (decl->STRING() != nullptr) {
          // string: will pad with zeros
        } else if (decl->initList() != nullptr) {
          if (decl->initList()->pad() != nullptr) {
            if (decl->initList()->pad()->value() != nullptr) {
              // pad with value
              values_str.resize(var.table_size, gatherValue(decl->initList()->pad()->value()));
            } else {
              // leave the rest uninitialized
              sl_assert(decl->initList()->pad()->UNINITIALIZED() != nullptr);
            }
          } else {
            // not allowed
            if (values_str.empty()) {
              reportError(sourceloc(decl), "table initializer is empty, use e.g. ' = {pad(0)}' to fill with zeros, or '= uninitialized' to skip initialization");
            } else {
              reportError(sourceloc(decl), "too few values in table initialization, you may use '{...,pad(v)}' to fill the table remainder with v.");
            }
          }
        } else {
          // not allowed (case should not happen)
          reportError(sourceloc(decl), "too few values in table initialization");
        }
      } else {
        // not allowed
        reportError(sourceloc(decl), "too many values in table initialization");
      }
    }
    // store
    var.init_values.resize(values_str.size(), "0");
    ForIndex(i, values_str.size()) {
      var.init_values[i] = values_str[i];
    }
  }
}

// -------------------------------------------------

void Algorithm::gatherDeclarationMemory(siliceParser::DeclarationMemoryContext* decl, t_combinational_block *_current)
{
  t_subroutine_nfo *sub = nullptr;
  if (_current) {
    sub = _current->context.subroutine;
  }
  if (sub != nullptr) {
    reportError(sourceloc(decl), "subroutine '%s': a memory cannot be instanced within a subroutine", sub->name.c_str());
  }
  // check for duplicates
  if (!isIdentifierAvailable(decl->IDENTIFIER()->getText())) {
    reportError(sourceloc(decl), "memory '%s': this name is already used by a prior declaration", decl->IDENTIFIER()->getText().c_str());
  }
  // gather memory nfo
  t_mem_nfo mem;
  mem.name = decl->name->getText();
  string memid = "";
  if (decl->BRAM() != nullptr) {
    mem.mem_type = BRAM;
    memid = "bram";
  } else if (decl->BROM() != nullptr) {
    mem.mem_type = BROM;
    memid = "brom";
  } else if (decl->DUALBRAM() != nullptr) {
    mem.mem_type = DUALBRAM;
    memid = "dualport_bram";
  } else if (decl->SIMPLEDUALBRAM() != nullptr) {
    mem.mem_type = SIMPLEDUALBRAM;
    memid = "simple_dualport_bram";
  } else {
    reportError(sourceloc(decl), "internal error (memory declaration 1)");
  }
  // check if supported
  auto C = CONFIG.keyValues().find(memid + "_supported");
  if (C == CONFIG.keyValues().end()) {
    reportError(sourceloc(decl), "memory type '%s' is not supported by this hardware", memid.c_str());
  } else if (C->second != "yes") {
    reportError(sourceloc(decl), "memory type '%s' is not supported by this hardware", memid.c_str());
  }
  // gather type and size
  splitType(decl->TYPE()->getText(), mem.type_nfo);
  if (decl->NUMBER() != nullptr) {
    mem.table_size = atoi(decl->NUMBER()->getText().c_str());
    if (mem.table_size <= 0) {
      reportError(sourceloc(decl), "memory has zero or negative size");
    }
  } else {
    mem.table_size = 0; // autosize from init
  }
  readInitList(decl, mem);
  // check
  if (mem.mem_type == BROM && mem.do_not_initialize) {
    reportError(sourceloc(decl), "a brom has to be initialized: initializer missing, or use a bram instead.");
  }
  // decl. line
  mem.srcloc = sourceloc(decl);
  // create bound variables for access
  std::vector<t_mem_member> members;
  switch (mem.mem_type)     {
  case BRAM:     members = c_BRAMmembers; break;
  case BROM:     members = c_BROMmembers; break;
  case DUALBRAM: members = c_DualPortBRAMmembers; break;
  case SIMPLEDUALBRAM: members = c_SimpleDualPortBRAMmembers; break;
  default: reportError(sourceloc(decl), "internal error (memory declaration 2)"); break;
  }
  // modifiers
  if (decl->memModifiers() != nullptr) {
    for (auto mod : decl->memModifiers()->memModifier()) {
      if (mod->memClocks() != nullptr) { // clocks
        // check clock signal exist
        if (!isVIO(mod->memClocks()->clk0->IDENTIFIER()->getText())
          && mod->memClocks()->clk0->IDENTIFIER()->getText() != ALG_CLOCK
          && mod->memClocks()->clk0->IDENTIFIER()->getText() != m_Clock) {
          reportError(sourceloc(mod->memClocks()->clk0->IDENTIFIER()),
            "clock signal '%s' not declared in dual port BRAM", mod->memClocks()->clk0->getText().c_str());
        }
        if (!isVIO(mod->memClocks()->clk1->IDENTIFIER()->getText())
          && mod->memClocks()->clk1->IDENTIFIER()->getText() != ALG_CLOCK
          && mod->memClocks()->clk1->IDENTIFIER()->getText() != m_Clock) {
          reportError(sourceloc(mod->memClocks()->clk1->IDENTIFIER()),
            "clock signal '%s' not declared in dual port BRAM", mod->memClocks()->clk1->getText().c_str());
        }
        // add
        mem.clocks.push_back(mod->memClocks()->clk0->IDENTIFIER()->getText());
        mem.clocks.push_back(mod->memClocks()->clk1->IDENTIFIER()->getText());
      } else if (mod->memNoInputLatch() != nullptr) { // no input latch
        if (mod->memDelayed() != nullptr) {
          reportError(sourceloc(mod->memNoInputLatch()),
            "memory cannot use both 'input!' and 'delayed' options");
        }
        mem.no_input_latch = true;
      } else if (mod->memDelayed() != nullptr) { // delayed input ( <:: )
        if (mod->memNoInputLatch() != nullptr) {
          reportError(sourceloc(mod->memDelayed()),
            "memory cannot use both 'input!' and 'delayed' options");
        }
        mem.delayed = true;
      } else if (mod->STRING() != nullptr) {
        mem.custom_template = mod->STRING()->getText();
        mem.custom_template = mem.custom_template.substr(1, mem.custom_template.size() - 2);
      } else {
        reportError(sourceloc(mod), "unknown modifier");
      }
    }
  }
  // members
  for (const auto& m : members) {
    t_var_nfo v;
    v.name = mem.name + "_" + m.name;
    mem.members.push_back(m.name);
    if (m.is_addr) {
      // address bus
      v.type_nfo.base_type = UInt;
      v.type_nfo.width     = justHigherPow2(mem.table_size);
    } else {
      // search config for width
      auto C = CONFIG.keyValues().find(mem.custom_template + "_" + m.name + "_width");
      if (C == CONFIG.keyValues().end() || mem.custom_template.empty()) {
        C = CONFIG.keyValues().find(memid + "_" + m.name + "_width");
      }
      if (C == CONFIG.keyValues().end()) {
        v.type_nfo.width     = mem.type_nfo.width;
      } else if (C->second == "1") {
        v.type_nfo.width     = 1;
      } else if (C->second == "data") {
        v.type_nfo.width     = mem.type_nfo.width;
      }
      // search config for type
      string sgnd = "";
      auto T = CONFIG.keyValues().find(mem.custom_template + "_" + m.name + "_type");
      if (T == CONFIG.keyValues().end() || mem.custom_template.empty()) {
        T = CONFIG.keyValues().find(memid + "_" + m.name + "_type");
      }
      if (T == CONFIG.keyValues().end()) {
        v.type_nfo.base_type = mem.type_nfo.base_type;
      } else if (T->second == "uint") {
        v.type_nfo.base_type = UInt;
      } else if (T->second == "int") {
        v.type_nfo.base_type = Int;
      } else if (T->second == "data") {
        v.type_nfo.base_type = mem.type_nfo.base_type;
      }
    }
    v.table_size = 0;
    v.init_values.push_back("0");
    v.init_at_startup = true;
    if (m.is_input) {
      v.access = e_InternalFlipFlop; // internal flip-flop to circumvent issue #102 (see also Yosys #2473)
    }
    addVar(v, _current, sourceloc(decl, decl->IDENTIFIER()->getSourceInterval()));
    if (m.is_input) {
      mem.in_vars.push_back(make_pair(m.name,v.name));
    } else {
      mem.out_vars.push_back(make_pair(m.name, v.name));
      m_VIOBoundToBlueprintOutputs[v.name] = WIRE "_mem_" + v.name;
    }
  }
  // add memory
  m_Memories.emplace_back(mem);
  m_MemoryNames.insert(make_pair(mem.name, (int)m_Memories.size()-1));
  // add group for member access and bindings
  m_VIOGroups.insert(make_pair(mem.name, decl));
}

// -------------------------------------------------

void Algorithm::getBindings(
  siliceParser::BpBindingListContext *bindings,
  std::vector<t_binding_nfo>& _vec_bindings,
  bool& _autobind) const
{
  if (bindings == nullptr) return;
  while (bindings != nullptr) {
    if (bindings->bpBinding() != nullptr) {
      if (bindings->bpBinding()->AUTOBIND() != nullptr) {
        _autobind = true;
      } else {
        // check if this is a group binding
        if ((bindings->bpBinding()->BDEFINE() != nullptr || bindings->bpBinding()->BDEFINEDBL() != nullptr)) {
          // verify right is an identifier
          if (bindings->bpBinding()->right->IDENTIFIER() == nullptr) {
            reportError(
              sourceloc(bindings->bpBinding()),
              "expecting an identifier on the right side of a group binding");
          }
          auto G = m_VIOGroups.find(bindings->bpBinding()->right->getText());
          if (G != m_VIOGroups.end()) {
            // unfold all bindings, select direction automatically
            // NOTE: some members may not be used, these are excluded during auto-binding
            for (auto v : getGroupMembers(G->second)) {
              string member = v;
              t_binding_nfo nfo;
              nfo.left   = bindings->bpBinding()->left->getText() + "_" + member;
              nfo.right  = bindings->bpBinding()->right->IDENTIFIER()->getText() + "_" + member;
              nfo.srcloc = sourceloc(bindings->bpBinding());
              nfo.dir    = (bindings->bpBinding()->BDEFINE() != nullptr) ? e_Auto : e_AutoQ;
              _vec_bindings.push_back(nfo);
            }
            // skip to next
            bindings = bindings->bpBindingList();
            continue;
          }
        }
        // check if this binds an instance (e.g. through 'outputs()')
        if ((bindings->bpBinding()->LDEFINE() != nullptr || bindings->bpBinding()->LDEFINEDBL() != nullptr)
          && bindings->bpBinding()->right->IDENTIFIER() != nullptr) {
          auto I = m_InstancedBlueprints.find(bindings->bpBinding()->right->getText());
          if (I != m_InstancedBlueprints.end()) {
            reportError(sourceloc(bindings->bpBinding()), "direct binding of an instanced algorithm ('%s') no longer supported", I->second.blueprint_name.c_str());
          }
        }
        // standard binding
        t_binding_nfo nfo;
        nfo.left = bindings->bpBinding()->left->getText();
        if (bindings->bpBinding()->right->IDENTIFIER() != nullptr) {
          nfo.right = bindings->bpBinding()->right->IDENTIFIER()->getText();
        } else {
          sl_assert(bindings->bpBinding()->right->access() != nullptr);
          nfo.right = bindings->bpBinding()->right->access();
        }
        nfo.srcloc = sourceloc(bindings->bpBinding());
        if (bindings->bpBinding()->LDEFINE() != nullptr) {
          nfo.dir = e_Left;
        } else if (bindings->bpBinding()->LDEFINEDBL() != nullptr) {
          nfo.dir = e_LeftQ;
        } else if (bindings->bpBinding()->RDEFINE() != nullptr) {
          nfo.dir = e_Right;
        } else if (bindings->bpBinding()->BDEFINE() != nullptr) {
          nfo.dir = e_BiDir;
        } else {
          reportError(
            sourceloc(bindings->bpBinding()),
            "this binding operator can only be used on io groups");
        }
        _vec_bindings.push_back(nfo);
      }
    }
    bindings = bindings->bpBindingList();
  }
}

// -------------------------------------------------

void Algorithm::gatherDeclarationGroup(siliceParser::DeclarationInstanceContext* grp, t_combinational_block *_current)
{
  // check for duplicates
  if (!isIdentifierAvailable(grp->name->getText())) {
    reportError(sourceloc(grp), "group '%s': this name is already used by a prior declaration", grp->name->getText().c_str());
  }
  // gather
  auto G = m_KnownGroups.find(grp->blueprint->getText());
  if (G != m_KnownGroups.end()) {
    m_VIOGroups.insert(make_pair(grp->name->getText(), G->second));
    for (auto v : G->second->varList()->var()) {
      // create group variables
      t_var_nfo vnfo;
      std::string is_group;
      gatherVarNfo(v->declarationVar(), vnfo, false, _current, is_group);
      if (vnfo.type_nfo.base_type == Parameterized) {
        reportError(sourceloc(v), "group '%s': group member declarations cannot use 'sameas'", grp->name->getText().c_str());
      }
      vnfo.name = grp->name->getText() + "_" + vnfo.name;
      addVar(vnfo, _current, sourceloc(grp, grp->IDENTIFIER()[1]->getSourceInterval()));
    }
  } else {
    reportError(sourceloc(grp), "unknown group '%s'", grp->blueprint->getText().c_str());
  }
}

// -------------------------------------------------

// templated helper to search for vios definitions
template <typename T>
bool findVIO(std::string vio, std::unordered_map<std::string, int> names, std::vector<T> vars,Algorithm::t_var_nfo& _def)
{
  auto V = names.find(vio);
  if (V != names.end()) {
    _def = vars[V->second];
    return true;
  }
  return false;
}

// -------------------------------------------------

Algorithm::t_var_nfo Algorithm::getVIODefinition(std::string var,bool& _found) const
{
  t_var_nfo def;
  _found = true;
  if (findVIO(var, m_VarNames, m_Vars, def)) {
    return def;
  } else {
    return Blueprint::getVIODefinition(var, _found);
  }
}

// -------------------------------------------------

// templated helper to search for vios in findSameAsRoot
template <typename T>
std::string findSameAs(std::string vio,std::unordered_map<std::string,int> names,std::vector<T> vars)
{
  auto V = names.find(vio);
  if (V != names.end()) {
    if (!vars[V->second].type_nfo.same_as.empty()) {
      return vars[V->second].type_nfo.same_as;
    }
  }
  return "";
}

// -------------------------------------------------

std::string Algorithm::findSameAsRoot(std::string vio, const t_combinational_block_context *bctx) const
{
  do {
    // find vio
    vio = translateVIOName(vio, bctx);
    // search dependency and move up the chain
    std::string base = findSameAs(vio, m_VarNames, m_Vars);
    if (!base.empty()) {
      vio = base;
    } else {
      base = findSameAs(vio, m_InputNames, m_Inputs);
      if (!base.empty()) {
        vio = base;
      } else {
        base = findSameAs(vio, m_OutputNames, m_Outputs);
        if (!base.empty()) {
          vio = base;
        } else {
          base = findSameAs(vio, m_InOutNames, m_InOuts);
          if (base.empty()) {
            return vio;
          }
        }
      }
    }
  } while (1);
}

// -------------------------------------------------

void Algorithm::gatherTypeNfo(siliceParser::TypeContext *type, t_type_nfo &_nfo, const t_combinational_block *_current, string &_is_group)
{
  if (type->TYPE() != nullptr) {
    splitType(type->TYPE()->getText(), _nfo);
  } else if (type->SAMEAS() != nullptr) {
    // find base
    std::string base = type->base->getText() + (type->member != nullptr ? "_" + type->member->getText() : "");
    base = translateVIOName(base, &_current->context);
    // group?
    _is_group = "";
    auto G = m_VIOGroups.find(base);
    if (G != m_VIOGroups.end()) {
      _nfo.base_type = Parameterized;
      _nfo.same_as = "";
      _nfo.width = 0;
      _is_group = base;
      return;
    } else {
      // find base in standard vios
      if (isVIO(base)) {
        std::string typed_by = findSameAsRoot(base, &_current->context);
        _nfo.base_type = Parameterized;
        _nfo.same_as = typed_by;
        _nfo.width = 0;
      } else {
        reportError(sourceloc(type),
          "no known definition for '%s' (sameas can only be applied to interfaces, groups and simple variables)", type->base->getText().c_str());
      }
    }
  } else if (type->AUTO() != nullptr) {
    _nfo.base_type = Parameterized;
    _nfo.same_as   = "";
    _nfo.width     = 0;
  } else {
    sl_assert(false);
  }
}

// -------------------------------------------------

void Algorithm::gatherDeclarationInstance(siliceParser::DeclarationInstanceContext* alg, t_combinational_block *_current)
{
  t_subroutine_nfo *sub = nullptr;
  if (_current) {
    sub = _current->context.subroutine;
  }
  if (sub != nullptr) {
    reportError(sourceloc(alg), "subroutine '%s': algorithms cannot be instanced within subroutines", sub->name.c_str());
  }
  // check for duplicates
  if (alg->name != nullptr) {
    if (!isIdentifierAvailable(alg->name->getText())) {
      reportError(sourceloc(alg), "algorithm instance '%s': this name is already used by a prior declaration", alg->name->getText().c_str());
    }
  }
  // gather
  t_instanced_nfo nfo;
  nfo.srcloc.root     = alg;
  nfo.srcloc.interval = alg->getSourceInterval();
  nfo.blueprint_name  = alg->blueprint->getText();
  if (alg->name != nullptr) {
    nfo.instance_name = alg->name->getText();
  } else {
    static int count = 0;
    nfo.instance_name = nfo.blueprint_name + "_unnamed_" + std::to_string(count++);
  }
  nfo.instance_clock = m_Clock;
  nfo.instance_reset = m_Reset;
  if (alg->bpModifiers() != nullptr) {
    for (auto m : alg->bpModifiers()->bpModifier()) {
      if (m->sclock() != nullptr) {
        nfo.instance_clock = m->sclock()->IDENTIFIER()->getText();
      } else if (m->sreset() != nullptr) {
        nfo.instance_reset = m->sreset()->IDENTIFIER()->getText();
      } else if (m->sreginput() != nullptr) {
        nfo.instance_reginput = true;
      } else if (m->sspecialize() != nullptr) {
        std::string var = m->sspecialize()->IDENTIFIER()->getText();
        t_type_nfo tn;
        splitType(m->sspecialize()->TYPE()->getText(), tn);
        std::transform(var.begin(), var.end(), var.begin(),
          [](unsigned char c) -> unsigned char { return std::toupper(c); });
        string str_width = var + "_WIDTH";
        string str_init = var + "_INIT";
        string str_signed = var + "_SIGNED";
        nfo.specializations.parameters[str_width] = std::to_string(tn.width);
        nfo.specializations.parameters[str_init] = "";
        nfo.specializations.parameters[str_signed] = tn.base_type == Int ? "signed" : "";
      } else {
        reportError(sourceloc(m), "modifier not allowed during instantiation" );
      }
    }
  }
  nfo.instance_prefix = "_" + nfo.instance_name;
  if (m_InstancedBlueprints.find(nfo.instance_name) != m_InstancedBlueprints.end()) {
    reportError(nfo.srcloc, "an instance of the same name already exists");
  }
  nfo.autobind = false;
  getBindings(alg->bpBindingList(), nfo.bindings, nfo.autobind);
  m_InstancedBlueprints[nfo.instance_name] = nfo;
  m_InstancedBlueprintsInDeclOrder.push_back(nfo.instance_name);
}

// -------------------------------------------------

std::string Algorithm::translateVIOName(
  std::string                          vio,
  const t_combinational_block_context *bctx) const
{
  if (bctx != nullptr) {
     // first block rewrite rules
    if (!bctx->vio_rewrites.empty()) {
      const auto& Vrew = bctx->vio_rewrites.find(vio);
      if (Vrew != bctx->vio_rewrites.end()) {
        vio = Vrew->second;
      }
    }
    // then subroutine
    if (bctx->subroutine != nullptr) {
      const auto& Vsub = bctx->subroutine->vios.find(vio);
      if (Vsub != bctx->subroutine->vios.end()) {
        vio = Vsub->second;
      }
    }
    // then pipeline stage
    if (bctx->pipeline != nullptr) {
      const auto& Vpip = bctx->pipeline->pipeline->trickling_vios.find(vio);
      if (Vpip != bctx->pipeline->pipeline->trickling_vios.end()) {
        if (bctx->pipeline->stage_id > Vpip->second[0]) {
          vio = tricklingVIOName(vio, bctx->pipeline);
        }
      }
    }
  }
  return vio;
}

// -------------------------------------------------

// utility: splits a single binding string into its wire and range
static pair<string, v2i> splitBinding(std::string str)
{
  string wire, offset, width;
  v2i    range;
  istringstream  stream(str);
  getline(stream, wire, ',');
  getline(stream, offset, ',');
  getline(stream, width, ',');
  range[0] = stoi(offset);
  range[1] = stoi(width);
  return make_pair(wire, range);
}

// utility: splits a binding string into its constituants
static void splitBitBindings(std::string str, vector<pair<string, v2i> >& _bit_bindings)
{
  istringstream  stream(str);
  string s;
  while (getline(stream, s, ';')) {
    if (s.empty()) continue;
    _bit_bindings.push_back(splitBinding(s));
  }
}

std::string Algorithm::rewriteBinding(std::string var, const t_combinational_block_context *bctx, const t_instantiation_context& ictx) const
{
  auto w = m_VIOBoundToBlueprintOutputs.at(var);
  sl_assert(!w.empty());
  if (w[0] == ';') {
    vector<pair<string, v2i> > bit_bindings;
    splitBitBindings(w, bit_bindings);
    // get var width
    string bw = resolveWidthOf(var, ictx, t_source_loc());
    int ibw;
    try {
      ibw = stoi(bw);
    } catch (...) {
      reportError(t_source_loc(), "cannot determine width of bound variable '%s' (width string is '%s')", var.c_str(), bw.c_str());
    }
    // now we iterate bit by bit
    string concat;
    ForIndex(bit, ibw) {
      // find which range covers it, there should one at most
      pair<string, v2i> which;
      int which_bit = -1;
      for (auto r : bit_bindings) {
        if (bit >= r.second[0] && bit <= r.second[0] + r.second[1] - 1) {
          if (which.first.empty()) {
            which = r;
            which_bit = bit - r.second[0];
          } else {
            reportError(t_source_loc(), "bit %d of variable '%s' is bound to multiple outputs", bit, var.c_str());
          }
        }
      }
      string sep = concat.empty() ? "}" : ",";
      if (which.first.empty()) {
        concat = "1'b0" + sep + concat;
      } else {
        concat = which.first + "[" + to_string(which_bit) + "+:1]" + sep + concat;
      }
    }
    concat = "{" + concat;
    return concat;
  } else {
    return w;
  }
}

// -------------------------------------------------

std::string Algorithm::encapsulateIdentifier(std::string var, bool read_access, std::string rewritten, std::string suffix) const
{
  return rewritten + suffix;
}

// -------------------------------------------------

std::string Algorithm::rewriteIdentifier(
  std::string prefix, std::string var, std::string suffix,
  const t_combinational_block_context *bctx, const t_instantiation_context& ictx,
  const t_source_loc& srcloc,
  std::string ff, bool read_access,
  const t_vio_dependencies& dependencies,
  t_vio_ff_usage &_ff_usage, e_FFUsage ff_force) const
{
  sl_assert(!(!read_access && ff == FF_Q));
  if (var == ALG_RESET || var == ALG_CLOCK) {
    return var;
  } else if (var == m_Reset) { // cannot be ALG_RESET
    if (m_VIOBoundToBlueprintOutputs.find(var) == m_VIOBoundToBlueprintOutputs.end()) {
      reportError(srcloc, "custom reset signal has to be bound to a module output");
    }
    return rewriteBinding(var, bctx, ictx);
  } else if (var == m_Clock) { // cannot be ALG_CLOCK
    if (m_VIOBoundToBlueprintOutputs.find(var) == m_VIOBoundToBlueprintOutputs.end()) {
      reportError(srcloc, "custom clock signal has to be bound to a module output");
    }
    return rewriteBinding(var, bctx, ictx);
  } else {
    // vio? translate
    var = translateVIOName(var, bctx);
    // keep going
    if (isInput(var)) {
      return encapsulateIdentifier(var, read_access, ALG_INPUT + prefix + var, suffix);
    } else if (isInOut(var)) {
      reportError(srcloc, "cannot use inouts directly in expressions");
    } else if (isOutput(var)) {
      auto usage = m_Outputs.at(m_OutputNames.at(var)).usage;
      if (usage == e_Temporary) {
        // temporary
        updateFFUsage((e_FFUsage)((int)e_D | ff_force), read_access, _ff_usage.ff_usage[var]);
        return encapsulateIdentifier(var, read_access, FF_TMP + prefix + var, suffix);
      } else if (usage == e_FlipFlop) {
        // flip-flop
        if (ff == FF_Q) {
          if (dependencies.dependencies.count(var) > 0) {
            updateFFUsage((e_FFUsage)((int)e_D | ff_force), read_access, _ff_usage.ff_usage[var]);
            return encapsulateIdentifier(var, read_access, FF_D + prefix + var, suffix);
          } else {
            updateFFUsage((e_FFUsage)((int)e_Q | ff_force), read_access, _ff_usage.ff_usage[var]);
          }
        } else {
          sl_assert(ff == FF_D);
          updateFFUsage((e_FFUsage)((int)e_D | ff_force), read_access, _ff_usage.ff_usage[var]);
        }
        return encapsulateIdentifier(var, read_access, ff + prefix + var, suffix);
      } else if (usage == e_Bound) {
        // bound
        return encapsulateIdentifier(var, read_access, rewriteBinding(var, bctx, ictx), suffix);
      } else {
        reportError(srcloc, "internal error [%s, %d]", __FILE__, __LINE__);
      }
    } else {
      auto V = m_VarNames.find(var);
      if (V == m_VarNames.end()) {
        reportError(srcloc, "variable '%s' was never declared", var.c_str());
      }
      if (m_Vars.at(V->second).usage == e_Bound) {
        // bound to an output?
        auto Bo = m_VIOBoundToBlueprintOutputs.find(var);
        if (Bo != m_VIOBoundToBlueprintOutputs.end()) {
          return encapsulateIdentifier(var, read_access, rewriteBinding(var, bctx, ictx), suffix);
        }
        reportError(srcloc, "internal error [%s, %d]", __FILE__, __LINE__);
      } else {
        if (m_Vars.at(V->second).usage == e_Temporary) {
          // temporary
          updateFFUsage((e_FFUsage)((int)e_D | ff_force), read_access, _ff_usage.ff_usage[var]);
          return encapsulateIdentifier(var, read_access, FF_TMP + prefix + var, suffix);
        } else if (m_Vars.at(V->second).usage == e_Const) {
          // const
          return encapsulateIdentifier(var, read_access, FF_CST + prefix + var, suffix);
        } else if (m_Vars.at(V->second).usage == e_Wire) {
          // wire
          return encapsulateIdentifier(var, read_access, WIRE + prefix + var, suffix);
        } else {
          // flip-flop
          if (ff == FF_Q) {
            if (dependencies.dependencies.count(var) > 0) {
              updateFFUsage((e_FFUsage)((int)e_D | ff_force), read_access, _ff_usage.ff_usage[var]);
              return encapsulateIdentifier(var, read_access, FF_D + prefix + var, suffix);
            } else {
              updateFFUsage((e_FFUsage)((int)e_Q | ff_force), read_access, _ff_usage.ff_usage[var]);
            }
          } else {
            sl_assert(ff == FF_D);
            updateFFUsage((e_FFUsage)((int)e_D | ff_force), read_access, _ff_usage.ff_usage[var]);
          }
          return encapsulateIdentifier(var, read_access, ff + prefix + var, suffix);
        }
      }
    }
  }
  reportError(srcloc, "internal error [%s, %d]", __FILE__, __LINE__);
  return "";
}

// -------------------------------------------------

std::string Algorithm::resolveWidthOf(std::string vio, const t_instantiation_context &ictx, const t_source_loc& srcloc) const
{
  bool found    = false;
  t_var_nfo def = getVIODefinition(vio, found);
  if (!found) {
    reportError(srcloc, "cannot find VIO '%s' in widthof", vio.c_str());
  }
  return varBitWidth(def, ictx);
}

// -------------------------------------------------

std::string Algorithm::rewriteExpression(
  std::string prefix, antlr4::tree::ParseTree *expr,
  int __id,
  const t_combinational_block_context *bctx, const t_instantiation_context &ictx,
  std::string ff, bool read_access,
  const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const
{
  std::string result;
  if (expr->children.empty()) {
    auto term = dynamic_cast<antlr4::tree::TerminalNode*>(expr);
    if (term) {
      if (term->getSymbol()->getType() == siliceParser::IDENTIFIER) {
        return rewriteIdentifier(prefix, expr->getText(), "", bctx, ictx, sourceloc(term), ff, read_access, dependencies, _ff_usage);
      } else if (term->getSymbol()->getType() == siliceParser::CONSTANT) {
        return rewriteConstant(expr->getText());
      } else if (term->getSymbol()->getType() == siliceParser::REPEATID) {
        if (__id == -1) {
          reportError(sourceloc(term), "__id used outside of repeat block");
        }
        return std::to_string(__id);
      } else if (term->getSymbol()->getType() == siliceParser::TOUNSIGNED) {
        return "$unsigned";
      } else if (term->getSymbol()->getType() == siliceParser::TOSIGNED) {
        return "$signed";
      } else {
        return expr->getText() == "?" ? " ? " : expr->getText();
      }
    } else {
      return expr->getText() == "?" ? " ? " : expr->getText();
    }
  } else {
    auto access = dynamic_cast<siliceParser::AccessContext*>(expr);
    if (access) {
      std::ostringstream ostr;
      writeAccess(prefix, ostr, false, access, __id, bctx, ictx, ff, dependencies, _ff_usage);
      result = result + ostr.str();
    } else {
      bool recurse = true;
      // atom?
      auto atom = dynamic_cast<siliceParser::AtomContext *>(expr);
      if (atom) {
        if (atom->WIDTHOF() != nullptr) {
          recurse = false;
          std::string vio = atom->base->getText() + (atom->member != nullptr ? "_" + atom->member->getText() : "");
          vio = translateVIOName(vio, bctx);
          std::string wo  = resolveWidthOf(vio, ictx, sourceloc(atom));
          result = result + "(" + wo + ")";
        } else if (atom->DONE() != nullptr) {
          recurse = false;
          // find algorithm
          auto A = m_InstancedBlueprints.find(atom->algo->getText());
          if (A == m_InstancedBlueprints.end()) {
            reportError(sourceloc(atom),"cannot find instance '%s'",atom->algo->getText().c_str());
          } else {
            Algorithm *alg = dynamic_cast<Algorithm*>(A->second.blueprint.raw());
            if (alg == nullptr) {
              reportError(sourceloc(atom), "instance '%s' does not support isdone", atom->algo->getText().c_str());
            } else {
              result = result + "(" + WIRE + A->second.instance_prefix + "_" + ALG_DONE ")";
            }
          }
        }
      } else {
        // combcast?
        auto comcast = dynamic_cast<siliceParser::CombcastContext *>(expr);
        if (comcast) {
          recurse = false;
          result = result + rewriteExpression(prefix, expr->children[1], __id, bctx, ictx, ff, read_access, dependencies, _ff_usage);
        }
      }
      // recurse?
      if (recurse) {
        for (auto c : expr->children) {
          result = result + rewriteExpression(prefix, c, __id, bctx, ictx, ff, read_access, dependencies, _ff_usage);
        }
      }
    }
  }
  return result;
}

// -------------------------------------------------

bool Algorithm::isIdentifier(antlr4::tree::ParseTree *expr,std::string& _identifier) const
{
  if (expr->children.empty()) {
    auto term = dynamic_cast<antlr4::tree::TerminalNode*>(expr);
    if (term) {
      if (term->getSymbol()->getType() == siliceParser::IDENTIFIER) {
        _identifier = expr->getText();
        return true;
      } else  {
        return false;
      }
    } else {
      return false;
    }
  } else {
    auto access = dynamic_cast<siliceParser::AccessContext*>(expr);
    if (access) {
      return false;
    } else {
      // recurse
      if (expr->children.size() == 1) {
        return isIdentifier(expr->children.front(), _identifier);
      } else {
        return false;
      }
    }
  }
  return false;
}

// -------------------------------------------------

bool Algorithm::isAccess(antlr4::tree::ParseTree *expr, siliceParser::AccessContext *&_access) const
{
  if (expr->children.empty()) {
    auto term = dynamic_cast<antlr4::tree::TerminalNode *>(expr);
    if (term) {
      return false;
    }
  } else {
    auto access = dynamic_cast<siliceParser::AccessContext *>(expr);
    if (access) {
      _access = access;
      return true;
    } else {
      // recurse
      if (expr->children.size() == 1) {
        return isAccess(expr->children.front(), _access);
      } else {
        return false;
      }
    }
  }
  return false;
}

// -------------------------------------------------

bool Algorithm::isConst(antlr4::tree::ParseTree *expr, std::string& _const) const
{
  if (expr->children.empty()) {
    auto atom = dynamic_cast<siliceParser::AtomContext*>(expr);
    if (atom) {
      if (atom->NUMBER()) {
        _const = atom->getText();
        return true;
      } else if (atom->CONSTANT()) {
        _const = rewriteConstant(atom->getText());
        return true;
      } else if (atom->WIDTHOF()) {
        std::string vio = atom->base->getText() + (atom->member != nullptr ? "_" + atom->member->getText() : "");
        _const = resolveWidthOf(vio, t_instantiation_context(), sourceloc(atom));
        return true;
      } else {
        return false;
      }
    } else {
      auto term = dynamic_cast<antlr4::tree::TerminalNode*>(expr);
      if (term) {
        if (term->getSymbol()->getType() == siliceParser::CONSTANT) {
          _const = rewriteConstant(term->getText());
          return true;
        } else if (term->getSymbol()->getType() == siliceParser::NUMBER) {
          _const = term->getText();
          return true;
        }
      }
      return false;
    }
  } else {
    // recurse
    /// TODO: const expr 'flattening' (can remain an expression but flattened)
    if (expr->children.size() == 1) {
      return isConst(expr->children.front(), _const);
    } else {
      return false;
    }
  }
  return false;
}

// -------------------------------------------------

std::string Algorithm::gatherConstValue(siliceParser::ConstValueContext* ival) const
{
  if (ival->CONSTANT() != nullptr) {
    return rewriteConstant(ival->CONSTANT()->getText());
  } else if (ival->NUMBER() != nullptr) {
    std::string sign = ival->minus != nullptr ? "-" : "";
    return sign + ival->NUMBER()->getText();
  } else if (ival->WIDTHOF() != nullptr) {
    std::string vio = ival->base->getText() + (ival->member != nullptr ? "_" + ival->member->getText() : "");
    return resolveWidthOf(vio, t_instantiation_context(), sourceloc(ival));
  } else {
    sl_assert(false);
    return "";
  }
}

// -------------------------------------------------

void Algorithm::resetBlockName()
{
  m_NextBlockName = 1;
}

// -------------------------------------------------

std::string Algorithm::generateBlockName()
{
  return "__block_" + std::to_string(m_NextBlockName++);
}

// -------------------------------------------------

Algorithm::t_combinational_block *Algorithm::gatherBlock(siliceParser::BlockContext *block, t_combinational_block *_current, t_gather_context *_context)
{
  t_combinational_block *newblock = addBlock(generateBlockName(), _current, nullptr, sourceloc(block));
  _current->next(newblock);
  // gather declarations in new block
  gatherDeclarationList(block->declarationList(), newblock, true);
  // gather instructions in new block
  t_combinational_block *after     = gather(block->instructionList(), newblock, _context);
  // produce next block
  t_combinational_block *nextblock = addBlock(generateBlockName(), _current, nullptr, sourceloc(block));
  after->next(nextblock);
  return nextblock;
}

// -------------------------------------------------

Algorithm::t_combinational_block *Algorithm::splitOrContinueBlock(siliceParser::InstructionListContext* ilist, t_combinational_block *_current, t_gather_context *_context)
{
  if (ilist->state() != nullptr) {
    // start a new block
    bool no_skip = true;
    std::string name;
    if (ilist->state()->state_name != nullptr) {
      name = ilist->state()->state_name->getText();
    } else {
      name = generateBlockName();
    }
    t_combinational_block *block = addBlock(name, _current, nullptr, sourceloc(ilist));
    block->is_state     = true;    // block explicitely required to be a state (may become a sub-state)
    block->could_be_sub = false;   /// TODO command line option // no_skip; // could become a sub-state
    block->no_skip      = no_skip;
    _current->next(block);
    return block;
  } else {
    return _current;
  }
}

// -------------------------------------------------

Algorithm::t_combinational_block *Algorithm::gatherBreakLoop(siliceParser::BreakLoopContext* brk, t_combinational_block *_current, t_gather_context *_context)
{
  // current goes to after while
  if (_context->break_to == nullptr) {
    reportError(sourceloc(brk->BREAK()),"cannot break outside of a loop");
  }
  _current->next(_context->break_to);
  _context->break_to->is_state = true;
  // start a new block after the break
  t_combinational_block *block = addBlock(generateBlockName(), _current, nullptr, sourceloc(brk));
  // return block
  return block;
}

// -------------------------------------------------

Algorithm::t_combinational_block *Algorithm::gatherWhile(siliceParser::WhileLoopContext* loop, t_combinational_block *_current, t_gather_context *_context)
{
  // while header block
  t_combinational_block *while_header = addBlock("__while" + generateBlockName(), _current, nullptr, sourceloc(loop));
  _current->next(while_header);
  // iteration block
  t_combinational_block *iter = addBlock(generateBlockName(), _current, nullptr, sourceloc(loop));
  // block for after the while
  t_combinational_block *after = addBlock(generateBlockName(), _current);
  // parse the iteration block
  t_combinational_block *previous = _context->break_to;
  _context->break_to = after;
  t_combinational_block *iter_last = gather(loop->while_block, iter, _context);
  _context->break_to = previous;
  // after iteration go back to header
  iter_last->next(while_header);
  // add while to header
  while_header->while_loop(t_instr_nfo(loop->expression_0(), _current, _context->__id), iter, after);
  // set states
  while_header->is_state = true; // header has to be a state
  after->is_state = true; // after has to be a state
  return after;
}

// -------------------------------------------------

void Algorithm::gatherDeclaration(siliceParser::DeclarationContext *decl, t_combinational_block *_current, bool var_group_table_only)
{
  auto declvar   = dynamic_cast<siliceParser::DeclarationVarContext*>(decl->declarationVar());
  auto declwire  = dynamic_cast<siliceParser::DeclarationWireContext *>(decl->declarationWire());
  auto decltbl   = dynamic_cast<siliceParser::DeclarationTableContext*>(decl->declarationTable());
  auto instance  = dynamic_cast<siliceParser::DeclarationInstanceContext*>(decl->declarationInstance());
  auto declmem   = dynamic_cast<siliceParser::DeclarationMemoryContext*>(decl->declarationMemory());
  if (var_group_table_only) {
    if (declmem) {
      reportError(sourceloc(declmem->IDENTIFIER()),"cannot declare a memory here");
    }
    if (instance) {
      std::string name = instance->blueprint->getText();
      if (m_KnownGroups.find(name) == m_KnownGroups.end()) {
        reportError(sourceloc(instance),"cannot instantiate here");
      }
    }
  }
  if (declvar)        { gatherDeclarationVar(declvar, _current); }
  else if (declwire)  { gatherDeclarationWire(declwire, _current); }
  else if (decltbl)   { gatherDeclarationTable(decltbl, _current); }
  else if (declmem)   { gatherDeclarationMemory(declmem, _current); }
  else if (instance) {
    std::string name = instance->blueprint->getText();
    if (m_KnownGroups.find(name) != m_KnownGroups.end()) {
      gatherDeclarationGroup(instance, _current);
    } else {
      sl_assert(!var_group_table_only);
      gatherDeclarationInstance(instance, _current);
    }
  }
}

//-------------------------------------------------

void Algorithm::gatherPastCheck(siliceParser::Was_atContext *chk, t_combinational_block *_current, t_gather_context *_context)
{
  std::string target = chk->IDENTIFIER()->getText();
  int clock_cycles = 1;

  if (auto n = chk->NUMBER())
    clock_cycles = std::stoi(n->getText());

  m_PastChecks.push_back({ target, clock_cycles, hasNoFSM() ? nullptr : _current, chk });
}

//-------------------------------------------------

void Algorithm::gatherStableCheck(siliceParser::AssumestableContext *chk, t_combinational_block *_current, t_gather_context *_context)
{
  Algorithm::t_stable_check sc;
  sc.current_state  = hasNoFSM() ? nullptr : _current;
  sc.ctx.assume_ctx = chk;
  sc.isAssumption   = true;
  m_StableChecks.push_back(sc);
}

void Algorithm::gatherStableCheck(siliceParser::AssertstableContext *chk, t_combinational_block *_current, t_gather_context *_context)
{
  Algorithm::t_stable_check sc;
  sc.current_state  = hasNoFSM() ? nullptr : _current;
  sc.ctx.assert_ctx = chk;
  sc.isAssumption   = false;
  m_StableChecks.push_back(sc);
}

//-------------------------------------------------

void Algorithm::gatherStableinputCheck(siliceParser::StableinputContext *ctx, t_combinational_block *_current, t_gather_context *_context)
{
  if (auto id = ctx->idOrIoAccess()->IDENTIFIER()) {
    // single identifier
    std::string base = id->getText();
    base = translateVIOName(base, &_current->context);

    if (!isInput(base) && !isInOut(base)) {
      reportError(sourceloc(ctx), "%s is not an input/inout", base.c_str());
    } else {
      m_StableInputChecks.push_back({ ctx, base });
    }
  } else {
    // group identifier
    auto id_ = ctx->idOrIoAccess()->ioAccess();
    std::string base = id_->base->getText();
    std::string member = id_->IDENTIFIER(1)->getText();

    auto G = m_VIOGroups.find(base);
    if (G != m_VIOGroups.end()) {
      verifyMemberGroup(member, G->second);
      // produce the variable name
      std::string vname = base + "_" + member;

      if (!isInput(vname) && !isInOut(vname)) {
        reportError(sourceloc(ctx), "%s is not an input/inout", (base + "." + member).c_str());
      } else {
        m_StableInputChecks.push_back({ ctx, base });
      }
    } else {
      reportError(sourceloc(id_),
        "cannot find accessed base.member '%s.%s'", base.c_str(), member.c_str());
    }
  }
}

//-------------------------------------------------

int Algorithm::gatherDeclarationList(siliceParser::DeclarationListContext* decllist, t_combinational_block *_current, bool var_group_table_only)
{
  if (decllist == nullptr) {
    return 0;
  }
  int num = 0;
  siliceParser::DeclarationListContext *cur_decllist = decllist;
  while (cur_decllist->declaration() != nullptr) {
    siliceParser::DeclarationContext* decl = cur_decllist->declaration();
    gatherDeclaration(decl, _current, var_group_table_only);
    cur_decllist = cur_decllist->declarationList();
    ++num;
  }
  return num;
}

// -------------------------------------------------

bool Algorithm::isIdentifierAvailable(std::string name) const
{
  if (m_Subroutines.count(name) > 0) {
    return false;
  }
  if (m_InstancedBlueprints.count(name) > 0) {
    return false;
  }
  if (m_VarNames.count(name) > 0) {
    return false;
  }
  if (m_InputNames.count(name) > 0) {
    return false;
  }
  if (m_OutputNames.count(name) > 0) {
    return false;
  }
  if (m_InOutNames.count(name) > 0) {
    return false;
  }
  if (m_MemoryNames.count(name) > 0) {
    return false;
  }
  return true;
}

// -------------------------------------------------

/// TODO: group as parameter?
Algorithm::t_combinational_block *Algorithm::gatherSubroutine(siliceParser::SubroutineContext* sub, t_combinational_block *_current, t_gather_context *_context)
{
  if (_current->context.subroutine != nullptr) {
    reportError(sourceloc(sub->IDENTIFIER()), "subroutine '%s': cannot declare a subroutine in another", sub->IDENTIFIER()->getText().c_str());
  }
  t_subroutine_nfo *nfo = new t_subroutine_nfo;
  // subroutine name
  nfo->name = sub->IDENTIFIER()->getText();
  // check for duplicates
  if (!isIdentifierAvailable(nfo->name)) {
    reportError(sourceloc(sub->IDENTIFIER()),"subroutine '%s': this name is already used by a prior declaration", nfo->name.c_str());
  }
  // subroutine block
  t_combinational_block *subb = addBlock(SUB_ENTRY_BLOCK + nfo->name, _current, nullptr, sourceloc(sub));
  subb->context.subroutine    = nfo;
  nfo->top_block              = subb;
  // subroutine local declarations
  int numdecl = gatherDeclarationList(sub->declarationList(), subb, true);
  // cross ref between block and subroutine
  // gather inputs/outputs and access constraints
  sl_assert(sub->subroutineParamList() != nullptr);
  // constraint?
  for (auto P : sub->subroutineParamList()->subroutineParam()) {
    if (P->READ() != nullptr) {
      nfo->allowed_reads.insert(P->IDENTIFIER()->getText());
      // if group, add all members
      auto G = m_VIOGroups.find(P->IDENTIFIER()->getText());
      if (G != m_VIOGroups.end()) {
        for (auto v : getGroupMembers(G->second)) {
          string mbr = P->IDENTIFIER()->getText() + "_" + v;
          nfo->allowed_reads.insert(mbr);
        }
      }
    } else if (P->WRITE() != nullptr) {
      nfo->allowed_writes.insert(P->IDENTIFIER()->getText());
      // if group, add all members
      auto G = m_VIOGroups.find(P->IDENTIFIER()->getText());
      if (G != m_VIOGroups.end()) {
        for (auto v : getGroupMembers(G->second)) {
          string mbr = P->IDENTIFIER()->getText() + "_" + v;
          nfo->allowed_writes.insert(mbr);
        }
      }
    } else if (P->READWRITE() != nullptr) {
      nfo->allowed_reads.insert(P->IDENTIFIER()->getText());
      nfo->allowed_writes.insert(P->IDENTIFIER()->getText());
      // if group, add all members
      auto G = m_VIOGroups.find(P->IDENTIFIER()->getText());
      if (G != m_VIOGroups.end()) {
        for (auto v : getGroupMembers(G->second)) {
          string mbr = P->IDENTIFIER()->getText() + "_" + v;
          nfo->allowed_reads.insert(mbr);
          nfo->allowed_writes.insert(mbr);
        }
      }
    } else if (P->CALLS() != nullptr) {
      // add to list, check is in checkPermissions
      nfo->allowed_calls.insert(P->IDENTIFIER()->getText());
    } else if (P->input() != nullptr || P->output() != nullptr) {
      // input or output?
      std::string in_or_out;
      std::string ioname;
      siliceParser::TypeContext *type = nullptr;
      int tbl_size = 0;
      if (P->input() != nullptr) {
        in_or_out = "i";
        if (P->input()->declarationTable() != nullptr) {
          reportError(sourceloc(P),
            "subroutine '%s' input '%s', tables as input are not yet supported",
            nfo->name.c_str(), ioname.c_str());
        }
        ioname = P->input()->declarationVar()->IDENTIFIER()->getText();
        type = P->input()->declarationVar()->type();
        nfo->inputs.push_back(ioname);
      } else {
        in_or_out = "o";
        if (P->output()->declarationTable() != nullptr) {
          reportError(sourceloc(P),
            "subroutine '%s' output '%s', tables as output are not yet supported",
            nfo->name.c_str(), ioname.c_str());
        }
        ioname = P->output()->declarationVar()->IDENTIFIER()->getText();
        type   = P->output()->declarationVar()->type();
        nfo->outputs.push_back(ioname);
      }
      // check for name collisions
      if (m_InputNames.count(ioname) > 0
        || m_OutputNames.count(ioname) > 0
        || m_VarNames.count(ioname) > 0
        || ioname == m_Clock || ioname == m_Reset) {
        reportError(sourceloc(P),
          "subroutine '%s' input/output '%s' is using the same name as a host VIO, clock or reset",
          nfo->name.c_str(), ioname.c_str());
      }
      // insert variable in host for each input/output
      t_var_nfo var;
      var.name = in_or_out + "_" + nfo->name + "_" + ioname;
      var.table_size = tbl_size;
      // get type
      sl_assert(type != nullptr);
      std::string is_group;
      gatherTypeNfo(type, var.type_nfo, _current, is_group);
      if (!is_group.empty()) {
        reportError(sourceloc(type), "'sameas' in subroutine declaration cannot be refering to a group or interface");
      }
      // init values
      var.init_values.resize(max(var.table_size, 1), "0");
      var.do_not_initialize = true;
      // insert var
      insertVar(var, _current);
      // record in subroutine
      nfo->vios.insert(std::make_pair(ioname, var.name));
      // add to allowed read/write list
      if (P->input() != nullptr) {
        nfo->allowed_reads.insert(var.name);
      } else {
        nfo->allowed_writes.insert(var.name);
        nfo->allowed_reads.insert(var.name);
      }
      nfo->top_block->declared_vios.insert(var.name);
    }
  }
  // parse the subroutine
  t_combinational_block *sub_last = gather(sub->instructionList(), subb, _context);
  // add return from last
  sub_last->return_from(nfo->name,m_SubroutinesCallerReturnStates);
  // subroutine has to be a state
  subb->is_state = true;
  // record as a know subroutine
  m_Subroutines.insert(std::make_pair(nfo->name, nfo));
  // keep going with current
  return _current;
}

// -------------------------------------------------

std::string Algorithm::subroutineVIOName(std::string vio, const t_subroutine_nfo *sub)
{
  return "v_" + sub->name + "_" + vio;
}

// -------------------------------------------------

std::string Algorithm::blockVIOName(std::string vio, const t_combinational_block *host)
{
  if (host->block_name != "_top") {
    return host->block_name + "_" + vio;
  } else {
    return vio;
  }
}

// -------------------------------------------------

std::string Algorithm::tricklingVIOName(std::string vio, const t_pipeline_nfo *nfo, int stage) const
{
  return nfo->name + "_" + std::to_string(stage) + "_" + vio;
}

// -------------------------------------------------

std::string Algorithm::tricklingVIOName(std::string vio, const t_pipeline_stage_nfo *nfo) const
{
  return tricklingVIOName(vio, nfo->pipeline, nfo->stage_id);
}

// -------------------------------------------------

/*
Pipelining rules
- a variable starts trickly when written in a stage
- a variable read before being written has its value at exact moment
- a variable bound to an output is never trickled
  => should necessarily be the case and these cannot be written!
- inputs and outputs never trickle, outputs can be written from a single stage
*/
Algorithm::t_combinational_block *Algorithm::gatherPipeline(siliceParser::PipelineContext* pip, t_combinational_block *_current, t_gather_context *_context)
{
  if (_current->context.pipeline != nullptr) {
    reportError(sourceloc(pip), "pipelines cannot be nested");
  }
  const t_subroutine_nfo *sub = _current->context.subroutine;
  t_pipeline_nfo   *nfo = new t_pipeline_nfo();
  m_Pipelines.push_back(nfo);
  // name of the pipeline
  nfo->name = "__pip_" + std::to_string(pip->getStart()->getLine());
  // add a block for after pipeline
  t_combinational_block *after = addBlock(generateBlockName(), _current);
  // go through the pipeline
  // -> track read/written
  std::unordered_map<std::string,std::vector<int> > read_at, written_at;
  std::unordered_set<std::string> written_outputs;
  std::unordered_set<std::string> written_outside;
  // -> for each stage block
  t_combinational_block *prev = _current;
  // -> stage number
  int stage = 0;
  for (auto b : pip->block()) {
    // stage info
    t_pipeline_stage_nfo *snfo = new t_pipeline_stage_nfo();
    nfo ->stages.push_back(snfo);
    snfo->pipeline = nfo;
    snfo->stage_id = stage;
    // blocks
    t_combinational_block_context ctx  = { _current->context.subroutine, snfo, _current->context.parent_scope, _current->context.vio_rewrites };
    t_combinational_block *stage_start = addBlock("__stage_" + generateBlockName(), _current, &ctx, sourceloc(b));
    t_combinational_block *stage_end   = gather(b, stage_start, _context);
    // check this is a combinational chain
    if (!isStateLessGraph(stage_start)) {
      reportError(sourceloc(b),"pipeline stages have to be one-cycle only");
    }
    // check VIO access
    // gather read/written for block
    std::unordered_set<std::string> read, written;
    determineVIOAccess(b, m_VarNames,    &_current->context, read, written);
    // check written vars (will start trickling) are not written  outside of pipeline before
    for (auto w : written) {
      if (written_outside.count(w) != 0) {
        reportError(sourceloc(b), "variable '%s' is assigned to outside of pipeline (^=) by an earlier stage", w.c_str());
      }
    }
    // check no output is written from two stages
    std::unordered_set<std::string> o_read, o_written;
    determineVIOAccess(b, m_OutputNames, &_current->context, o_read, o_written);
    for (auto ow : o_written) {
      if (written_outputs.count(ow) > 0) {
        reportError(sourceloc(b), "output '%s' is written from two different pipeline stages", ow.c_str());
      }
      written_outputs.insert(ow);
    }
    // check outside of pipeline assignments: not written to outside from two stages, not written using both = and v= or ^=
    std::unordered_set<std::string> ex_written, ex_written_before, ex_written_after, not_ex_written;
    determineOutOfPipelineAssignments(b, m_VarNames, &_current->context, ex_written_before, ex_written_after, not_ex_written);
    // record written outside and before for the stage
    snfo->written_before = ex_written_before;
    // merge both sets
    ex_written.insert(ex_written_before.begin(), ex_written_before.end());
    ex_written.insert(ex_written_after.begin(), ex_written_after.end());
    for (auto w : ex_written) {
      // not written to outside from two stages
      if (written_outside.count(w) > 0) {
        reportError(sourceloc(b), "variable '%s' is assigned to outside of pipeline (v= or ^=) from two different stages", w.c_str());
      }
      written_outside.insert(w);
      // not written with both = and ^=/v= within same stage
      if (not_ex_written.count(w) != 0) {
        reportError(sourceloc(b), "variable '%s' cannot be assigned with both = and v= (or ^=)",w.c_str());
      }
      // not trickling before
      if (written_at.count(w) != 0) {
        reportError(sourceloc(b), "variable '%s' is assigned to outside of pipeline (^= or v=) while already trickling from a previous stage", w.c_str());
      }
      // exclude var from written set (cancels trickling)
      written.erase(w);
    }
    // -> merge
    for (auto r : read) {
      read_at[r].push_back(stage);
    }
    for (auto w : written) {
      written_at[w].push_back(stage);
    }
    // set next stage
    prev->pipeline_next(stage_start, stage_end);
    // advance
    prev = stage_end;
    stage++;
  }
  // set next of last stage
  prev->next(after);
  // set of trickling variable
  std::set<std::string> trickling_vios;
  // check written variables
  for (auto w : written_at) {
    // trickling?
    bool trickling = false;
    // min/max for read
    int minr = std::numeric_limits<int>::max(), maxr = std::numeric_limits<int>::min();
    if (read_at.count(w.first) > 0) {
      minr = read_at.at(w.first).front();
      maxr = read_at.at(w.first).back();
    }
    // min/max for write
    int minw = w.second.front();
    int maxw = w.second.back();
    // decide
    if (minw < maxr) {
      // the variable is read after being written, it has to trickle
      sl_assert(read_at.count(w.first) > 0);
      trickling = true;
      trickling_vios.insert(w.first);
      // std::cerr << "vio " << w.first << " trickling" << nxl;
    }
  }
  // report on read and written variables
#if 0
  for (auto r : read_at) {
    for (auto s : r.second) {
      std::cerr << "vio " << r.first << " read at stage " << s << nxl;
    }
  }
  for (auto w : written_at) {
    for (auto s : w.second) {
      std::cerr << "vio " << w.first << " written at stage " << s;
      std::cerr << nxl;
    }
  }
#endif
  // create trickling variables
  for (auto tv : trickling_vios) {
    // the first stage it is written
    int first_write = written_at.at(tv).front();
    // the last stage it is read
    int last_read   = read_at.at(tv).back();
    // register in pipeline info
    nfo->trickling_vios.insert(std::make_pair(tv, v2i(first_write,last_read)));
    // report
    std::cerr << tv << " trickling from " << first_write << " to " << last_read << nxl;
    // info from source var
    auto tws = determineVIOTypeWidthAndTableSize(translateVIOName(tv, &_current->context), sourceloc(pip));
    // generate one flip-flop per stage
    std::string pipeline_prev_name;
    ForRange(s, first_write, last_read) {
      // -> add variable
      t_var_nfo var;
      var.name       = tricklingVIOName(tv,nfo,s);
      var.pipeline_prev_name = pipeline_prev_name;
      pipeline_prev_name     = var.name;
      var.type_nfo   = get<0>(tws);
      var.table_size = get<1>(tws);
      var.init_values.resize(var.table_size > 0 ? var.table_size : 1, "0");
      var.access     = e_InternalFlipFlop;
      var.do_not_initialize = true;
      insertVar(var, _current);
    }
  }
  // done
  return after;
}

// -------------------------------------------------

Algorithm::t_combinational_block* Algorithm::gatherJump(siliceParser::JumpContext* jump, t_combinational_block* _current, t_gather_context* _context)
{
  std::string name = jump->IDENTIFIER()->getText();
  auto B = m_State2Block.find(name);
  if (B == m_State2Block.end()) {
    // forward reference
    _current->next(nullptr);
    t_forward_jump j;
    j.from = _current;
    j.jump = jump;
    m_JumpForwardRefs[name].push_back(j);
  } else {
    _current->next(B->second);
    B->second->is_state = true; // destination has to be a state
  }
  // start a new block just after the jump
  t_combinational_block *after = addBlock(generateBlockName(), _current, nullptr, sourceloc(jump));
  // return block after jump
  return after;
}

// -------------------------------------------------

Algorithm::t_combinational_block* Algorithm::gatherReturnFrom(siliceParser::ReturnFromContext* ret, t_combinational_block* _current, t_gather_context* _context)
{
  if (_current->context.subroutine != nullptr) {
    // add return at end of current
    _current->return_from(_current->context.subroutine->name,m_SubroutinesCallerReturnStates);
    // start a new block with a new state
    t_combinational_block* block = addBlock(generateBlockName(), _current, nullptr, sourceloc(ret));
    _current->is_state = true;
    return block;
  } else {
    _current->instructions.push_back(t_instr_nfo(ret, _current, _context->__id));
    return _current;
//     reportError(ret->getSourceInterval(), -1, "return can only be used from within subroutines and algorithms");
  }
}

// -------------------------------------------------

Algorithm::t_combinational_block* Algorithm::gatherSyncExec(siliceParser::SyncExecContext* sync, t_combinational_block* _current, t_gather_context* _context)
{
  if (_context->__id != -1) {
    reportError(sourceloc(sync->LARROW()),"repeat blocks cannot wait for a parallel execution");
  }
  // add sync as instruction, will perform the call
  _current->instructions.push_back(t_instr_nfo(sync, _current, _context->__id));
  // are we calling a subroutine?
  auto S = m_Subroutines.find(sync->joinExec()->IDENTIFIER()->getText());
  if (S != m_Subroutines.end()) {
    // are we in a subroutine?
    if (_current->context.subroutine) {
      // verify the call is allowed
      if (_current->context.subroutine->allowed_calls.count(S->first) == 0) {
        reportError(sourceloc(sync),
          "subroutine '%s' calls other subroutine '%s' without permssion\n\
                            add 'calls %s' to declaration if that was intended.",
          _current->context.subroutine->name.c_str(),
          S->first.c_str(), S->first.c_str());
      }
    }
    // yes! create a new block, call subroutine
    t_combinational_block* after = addBlock(generateBlockName(), _current, nullptr, sourceloc(sync));
    // has to be a state to return to
    after->is_state = true;
    // call subroutine
    _current->goto_and_return_to(S->second->top_block, after);
    // after is new current
    _current = after;
  }
  // gather the join exec, will perform the readback
  _current = gather(sync->joinExec(), _current, _context);
  return _current;
}

// -------------------------------------------------

Algorithm::t_combinational_block *Algorithm::gatherJoinExec(siliceParser::JoinExecContext* join, t_combinational_block *_current, t_gather_context *_context)
{
  if (_context->__id != -1) {
    reportError(sourceloc(join->LARROW()), "repeat blocks cannot wait a parallel execution");
  }
  // are we calling a subroutine?
  auto S = m_Subroutines.find(join->IDENTIFIER()->getText());
  if (S == m_Subroutines.end()) { // no, waiting for algorithm
    // block for the wait
    t_combinational_block* waiting_block = addBlock(generateBlockName(), _current, nullptr, sourceloc(join));
    waiting_block->is_state = true; // state for waiting
    // enter wait after current
    _current->next(waiting_block);
    // block for after the wait
    t_combinational_block* next_block = addBlock(generateBlockName(), _current);
    next_block->is_state = true; // state to goto after the wait
    // ask current block to wait the algorithm termination
    waiting_block->wait(sourceloc(join), join->IDENTIFIER()->getText(), waiting_block, next_block);
    // first instruction in next block will read result
    next_block->instructions.push_back(t_instr_nfo(join, _current, _context->__id));
    // use this next block now
    return next_block;
  } else {
    // subroutine, simply readback results
    _current->instructions.push_back(t_instr_nfo(join, _current, _context->__id));
    return _current;
  }
}

// -------------------------------------------------

bool Algorithm::isStateLessGraph(t_combinational_block *head) const
{
  std::queue< t_combinational_block* > q;
  std::unordered_set< t_combinational_block* > visited;

  q.push(head);
  while (!q.empty()) {
    auto cur = q.front();
    q.pop();
    visited.insert(cur);
    // test
    if (cur == nullptr) { // tags a forward ref (jump), not stateless
      return false;
    }
    if (cur->is_state || cur->is_sub_state) {
      return false; // not stateless
    }
    // recurse
    std::vector< t_combinational_block* > children;
    cur->getChildren(children);
    for (auto c : children) {
      if (visited.count(c) == 0) {
        q.push(c);
      }
    }
  }
  return true;
}

// -------------------------------------------------

void Algorithm::findNonCombinationalLeaves(const t_combinational_block *head, std::set<t_combinational_block*>& _leaves) const
{
  std::queue< t_combinational_block* >  q;
  std::unordered_set< t_combinational_block * > visited;
  // initialize queue
  {
    std::vector< t_combinational_block * > children;
    head->getChildren(children);
    for (auto c : children) {
      q.push(c);
    }
  }
  // explore
  while (!q.empty()) {
    auto cur = q.front();
    q.pop();
    visited.insert(cur);
    // test
    if (cur == nullptr) { // tags a forward ref (jump), not stateless
      _leaves.insert(cur);
    } else if (cur->is_state || cur->is_sub_state) {
      _leaves.insert(cur);
    } else {
      // recurse
      std::vector< t_combinational_block * > children;
      cur->getChildren(children);
      for (auto c : children) {
        if (visited.count(c) == 0) {
          q.push(c);
        }
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::getIdentifiers(
  siliceParser::IdOrIoAccessListContext*  idents,
  vector<string>&                        _vec_params,
  t_combinational_block*                 _current)
{
  // go through indentifier list
  while (idents != nullptr) {
    std::string var;
    if (idents->idOrIoAccess() != nullptr) {
      if (idents->idOrIoAccess()->IDENTIFIER() != nullptr) {
        var = idents->idOrIoAccess()->IDENTIFIER()->getText();
      } else {
        var = determineAccessedVar(idents->idOrIoAccess()->ioAccess(), &_current->context);
      }
    } else if (idents->constValue() != nullptr) {
      if (idents->constValue()->CONSTANT() == nullptr) {
        reportError(sourceloc(idents, idents->getSourceInterval()), "constants in circuitry instantiations have to be sized (e.g. 8h00)");
      }
      // get the constant
      std::string cst = gatherConstValue(idents->constValue());
      t_type_nfo cnfo;
      constantTypeInfo(idents->constValue()->getText(), cnfo);
      // create a dummy var
      static int count = 0;
      t_var_nfo vnfo;
      vnfo.type_nfo = cnfo;
      vnfo.do_not_initialize = false;
      vnfo.init_at_startup = true;
      vnfo.init_values.push_back(cst);
      vnfo.name = "circ_" + std::to_string(count++);
      addVar(vnfo, _current, sourceloc(idents, idents->getSourceInterval()));
      // use this var
      var = vnfo.name;
    } else {
      break;
    }
    _vec_params.push_back(var);
    idents = idents->idOrIoAccessList();
  }
}

// -------------------------------------------------

Algorithm::t_combinational_block* Algorithm::gatherCircuitryInst(siliceParser::CircuitryInstContext* ci, t_combinational_block* _current, t_gather_context* _context)
{
  // find circuitry in known circuitries
  std::string name = ci->IDENTIFIER()->getText();
  auto C = m_KnownCircuitries.find(name);
  if (C == m_KnownCircuitries.end()) {
    reportError(sourceloc(ci->IDENTIFIER()), "circuitry not yet declared");
  }
  // instantiate in a new block
  t_combinational_block* cblock = addBlock(generateBlockName() + "_" + name, _current, nullptr, sourceloc(ci));
  _current->next(cblock);
  // produce io rewrite rules for the block
  // -> gather ins outs
  vector< string > ins;
  vector< string > outs;
  for (auto io : C->second->ioList()->io()) {
    if (io->is_input != nullptr) {
      ins.push_back(io->IDENTIFIER()->getText());
    } else if (io->is_output != nullptr) {
      if (io->combinational != nullptr) {
        reportError(sourceloc(C->second->IDENTIFIER()),"a circuitry output is immediate by default");
      }
      outs.push_back(io->IDENTIFIER()->getText());
    } else if (io->is_inout != nullptr) {
      ins .push_back(io->IDENTIFIER()->getText());
      outs.push_back(io->IDENTIFIER()->getText());
    } else {
      reportError(sourceloc(C->second->IDENTIFIER()), "internal error (gatherCircuitryInst)");
    }
  }
  // -> get identifiers
  vector<string> ins_idents, outs_idents;
  getIdentifiers(ci->ins, ins_idents, _current);
  getIdentifiers(ci->outs, outs_idents, _current);
  // -> checks
  if (ins.size() != ins_idents.size()) {
    reportError(sourceloc(ci->IDENTIFIER()), "Incorrect number of inputs in circuitry instanciation (circuitry '%s')", name.c_str());
  }
  if (outs.size() != outs_idents.size()) {
    reportError(sourceloc(ci->IDENTIFIER()), "Incorrect number of outputs in circuitry instanciation (circuitry '%s')", name.c_str());
  }
  // -> rewrite rules
  ForIndex(i, ins.size()) {
    // -> closure on pre-existing rewrite rule
    std::string v = ins_idents[i];
    auto R        = cblock->context.vio_rewrites.find(v);
    if (R != cblock->context.vio_rewrites.end()) {
      v = R->second;
    }
    // -> add rule
    cblock->context.vio_rewrites[ins[i]] = v;
  }
  ForIndex(o, outs.size()) {
    // -> closure on pre-existing rewrite rule
    std::string v = outs_idents[o];
    auto R = cblock->context.vio_rewrites.find(v);
    if (R != cblock->context.vio_rewrites.end()) {
      v = R->second;
    }
    // -> add rule
    cblock->context.vio_rewrites[outs[o]] = v;
  }
  // gather code
  t_combinational_block* cblock_after = gather(C->second->block(), cblock, _context);
  // create a new block to continue with same context as _current
  t_combinational_block* after = addBlock(generateBlockName(), _current, nullptr, sourceloc(ci));
  cblock_after->next(after);
  return after;
}

// -------------------------------------------------

Algorithm::t_combinational_block *Algorithm::gatherIfElse(siliceParser::IfThenElseContext* ifelse, t_combinational_block *_current, t_gather_context *_context)
{
  t_combinational_block *if_block = addBlock(generateBlockName(), _current, nullptr, sourceloc(ifelse->if_block));
  t_combinational_block *else_block = addBlock(generateBlockName(), _current, nullptr, sourceloc(ifelse->else_block));
  // parse the blocks
  t_combinational_block *if_block_after = gather(ifelse->if_block, if_block, _context);
  t_combinational_block *else_block_after = gather(ifelse->else_block, else_block, _context);
  // create a block for after the if-then-else
  t_combinational_block *after = addBlock(generateBlockName(), _current);
  if_block_after->next(after);
  else_block_after->next(after);
  // add if_then_else to current
  _current->if_then_else(t_instr_nfo(ifelse->expression_0(), _current, _context->__id), if_block, else_block, after);
  // checks whether after has to be a state
  after->is_state = !isStateLessGraph(if_block) || !isStateLessGraph(else_block);
  return after;
}

// -------------------------------------------------

Algorithm::t_combinational_block *Algorithm::gatherIfThen(siliceParser::IfThenContext* ifthen, t_combinational_block *_current, t_gather_context *_context)
{
  t_combinational_block *if_block = addBlock(generateBlockName(), _current, nullptr, sourceloc(ifthen->if_block));
  t_combinational_block *else_block = addBlock(generateBlockName(), _current);
  // parse the blocks
  t_combinational_block *if_block_after = gather(ifthen->if_block, if_block, _context);
  // create a block for after the if-then-else
  t_combinational_block *after = addBlock(generateBlockName(), _current);
  if_block_after->next(after);
  else_block->next(after);
  // add if_then_else to current
  _current->if_then_else(t_instr_nfo(ifthen->expression_0(), _current, _context->__id), if_block, else_block, after);
  // checks whether after has to be a state
  after->is_state = !isStateLessGraph(if_block);
  return after;
}

// -------------------------------------------------

Algorithm::t_combinational_block* Algorithm::gatherSwitchCase(siliceParser::SwitchCaseContext* switchCase, t_combinational_block* _current, t_gather_context* _context)
{
  // create a block for after the switch-case
  t_combinational_block* after = addBlock(generateBlockName(), _current, nullptr, sourceloc(switchCase));
  // create a block per case statement
  std::vector<std::pair<std::string, t_combinational_block*> > case_blocks;
  for (auto cb : switchCase->caseBlock()) {
    t_combinational_block* case_block = addBlock(generateBlockName() + "_case", _current, nullptr, sourceloc(cb));
    std::string            value = "default";
    if (cb->case_value != nullptr) {
      value = gatherValue(cb->case_value);
    }
    case_blocks.push_back(std::make_pair(value, case_block));
    t_combinational_block* case_block_after = gather(cb->case_block, case_block, _context);
    case_block_after->next(after);
  }
  // if onehot, verifies expression is a single identifier
  bool is_onehot = (switchCase->ONEHOT() != nullptr);
  if (is_onehot) {
    string id;
    bool   isid = isIdentifier(switchCase->expression_0(),id);
    if (!isid) {
      reportError(sourceloc(switchCase), "onehot switch applies only to an identifer");
    }
  }
  // add switch-case to current
  _current->switch_case(is_onehot,t_instr_nfo(switchCase->expression_0(), _current, _context->__id), case_blocks, after);
  // checks whether after has to be a state
  bool is_state = false;
  for (auto b : case_blocks) {
    is_state = is_state || !isStateLessGraph(b.second);
  }
  after->is_state = is_state;
  return after;
}

// -------------------------------------------------

Algorithm::t_combinational_block *Algorithm::gatherRepeatBlock(siliceParser::RepeatBlockContext* repeat, t_combinational_block *_current, t_gather_context *_context)
{
  if (_context->__id != -1) {
    reportError(sourceloc(repeat->REPEATCNT()), "repeat blocks cannot be nested");
  } else {
    std::string rcnt = repeat->REPEATCNT()->getText();
    int num = atoi(rcnt.substr(0, rcnt.length() - 1).c_str());
    if (num <= 0) {
      reportError(sourceloc(repeat->REPEATCNT()), "repeat count has to be greater than zero");
    }
    ForIndex(id, num) {
      _context->__id = id;
      _current = gather(repeat->instructionList(), _current, _context);
    }
    _context->__id = -1;
  }
  return _current;
}

// -------------------------------------------------

void Algorithm::gatherAlwaysAssigned(siliceParser::AlwaysAssignedListContext* alws, t_combinational_block *always)
{
  while (alws) {
    auto alw = dynamic_cast<siliceParser::AlwaysAssignedContext*>(alws->alwaysAssigned());
    if (alw) {
      always->instructions.push_back(t_instr_nfo(alw, always, -1));
      // check syntax
      if (alw->LDEFINE() != nullptr || alw->LDEFINEDBL() != nullptr) {
        reportError(sourceloc(alws), "always assignement can only use := or ::=");
      }
      // check for double flip-flop
      if (alw->ALWSASSIGNDBL() != nullptr) {
        // insert temporary variable
        t_var_nfo var;
        var.name = "delayed_" + std::to_string(alw->getStart()->getLine()) + "_" + std::to_string(alw->getStart()->getCharPositionInLine());
        t_type_nfo typenfo = determineAccessTypeAndWidth(nullptr, alw->access(), alw->IDENTIFIER());
        var.table_size     = 0;
        var.type_nfo       = typenfo;
        var.init_values.push_back("0");
        var.do_not_initialize = true;
        insertVar(var, always);
      }
    }
    alws = alws->alwaysAssignedList();
  }
}

// -------------------------------------------------

void Algorithm::checkPermissions(antlr4::tree::ParseTree *node, t_combinational_block *_current)
{
  // gather info for checks
  std::unordered_set<std::string> all;
  std::unordered_set<std::string> read, written;
  determineVIOAccess(node, m_VarNames   , &_current->context, read, written);
  determineVIOAccess(node, m_OutputNames, &_current->context, read, written);
  determineVIOAccess(node, m_InputNames , &_current->context, read, written);
  for (auto R : read)    { all.insert(R); }
  for (auto W : written) { all.insert(W); }
  // in subroutine
  std::unordered_set<std::string> insub;
  if (_current->context.subroutine != nullptr) {
    for (auto R : read) {
      if (_current->context.subroutine->allowed_reads.count(R) == 0) {
        reportError(sourceloc(node), "variable '%s' is read by subroutine '%s' without explicit permission", R.c_str(), _current->context.subroutine->name.c_str());
      }
    }
    for (auto W : written) {
      if (_current->context.subroutine->allowed_writes.count(W) == 0) {
        reportError(sourceloc(node), "variable '%s' is written by subroutine '%s' without explicit permission", W.c_str(), _current->context.subroutine->name.c_str());
      }
    }
  }
  // block scope
  // -> attempt to locate variable in parent scope
  for (auto V : all) {
    if (isInputOrOutput(V) || isInOut(V)) {
      continue;   // ignore input/output/inout
    }
    const t_combinational_block *visiting = _current;
    bool found = false;
    while (visiting != nullptr) {
      if (visiting->declared_vios.count(V) > 0) {
        found = true; break;
      }
      visiting = visiting->context.parent_scope;
    }
    if (!found) {
      reportError(sourceloc(node), "variable '%s' is either unknown or out of scope", V.c_str());
    }
  }
}

// -------------------------------------------------

void Algorithm::gatherInputNfo(siliceParser::InputContext* input, t_inout_nfo& _io, const t_combinational_block *_current)
{
  if (input->declarationVar() != nullptr) {
    _io.srcloc = sourceloc(input->declarationVar()->IDENTIFIER());
    std::string is_group;
    gatherVarNfo(input->declarationVar(), _io, true, _current, is_group);
    if (_io.type_nfo.base_type == Parameterized && !is_group.empty()) {
      reportError(sourceloc(input), "input '%s': 'sameas' on group/interface inputs is not yet supported", _io.name.c_str());
    }
    if (!_io.init_at_startup && !_io.init_values.empty()) {
      reportError(sourceloc(input), "input '%s': only startup initialization values are possible on inputs", _io.name.c_str());
    }
  } else if (input->declarationTable() != nullptr) {
    reportError(sourceloc(input), "input '%s': tables as input are not yet supported", _io.name.c_str());
    // gatherTableNfo(input->declarationTable(), _io);
  } else {
    sl_assert(false);
  }
}

// -------------------------------------------------

void Algorithm::gatherOutputNfo(siliceParser::OutputContext* output, t_output_nfo& _io, const t_combinational_block *_current)
{
  if (output->declarationVar() != nullptr) {
    _io.srcloc = sourceloc(output->declarationVar()->IDENTIFIER());
    std::string is_group;
    gatherVarNfo(output->declarationVar(), _io, true, _current, is_group);
    if (_io.type_nfo.base_type == Parameterized && !is_group.empty()) {
      reportError(sourceloc(output), "output '%s': 'sameas' on group/interface outputs is not yet supported", _io.name.c_str());
    }
  } else if (output->declarationTable() != nullptr) {
    reportError(sourceloc(output), "output '%s': tables as output are not yet supported", _io.name.c_str());
    // gatherTableNfo(output->declarationTable(), _io);
  } else {
    sl_assert(false);
  }
  _io.combinational         = (output->combinational != nullptr) || (output->combinational_nocheck != nullptr);
  _io.combinational_nocheck = (output->combinational_nocheck != nullptr);
}

// -------------------------------------------------

void Algorithm::gatherInoutNfo(siliceParser::InoutContext* inout, t_inout_nfo& _io, const t_combinational_block *_current)
{
  if (inout->declarationVar() != nullptr) {
    _io.srcloc = sourceloc(inout->declarationVar()->IDENTIFIER());
    std::string is_group;
    gatherVarNfo(inout->declarationVar(), _io, true, _current, is_group);
    if (_io.type_nfo.base_type == Parameterized && !is_group.empty()) {
      reportError(sourceloc(inout), "inout '%s': 'sameas' on group/interface inouts is not yet supported", _io.name.c_str());
    }
    if (!_io.init_values.empty()) {
      reportError(sourceloc(inout), "inout '%s': initialization values are not possible on inouts", _io.name.c_str());
    }
  } else if (inout->declarationTable() != nullptr) {
    reportError(sourceloc(inout), "inout '%s': tables as inout are not supported", _io.name.c_str());
  } else {
    sl_assert(false);
  }
}

// -------------------------------------------------

void Algorithm::gatherIoDef(siliceParser::IoDefContext *iod, const t_combinational_block *_current)
{
  if (iod->ioList() != nullptr || iod->INPUT() != nullptr || iod->OUTPUT() != nullptr) {
    gatherIoGroup(iod,_current);
  } else {
    gatherIoInterface(iod);
  }
}

// -------------------------------------------------

template <typename T>
void var_nfo_copy(T& _dst,const Algorithm::t_var_nfo &src)
{
  _dst.name               = src.name;
  _dst.type_nfo           = src.type_nfo;
  _dst.init_values        = src.init_values;
  _dst.table_size         = src.table_size;
  _dst.do_not_initialize  = src.do_not_initialize;
  _dst.init_at_startup    = src.init_at_startup;
  _dst.pipeline_prev_name = src.pipeline_prev_name;
  _dst.access             = src.access;
  _dst.usage              = src.usage;
  _dst.attribs            = src.attribs;
  _dst.srcloc             = src.srcloc;
}

// -------------------------------------------------

void Algorithm::gatherIoGroup(siliceParser::IoDefContext *iog, const t_combinational_block *_current)
{
  // find group declaration
  auto G = m_KnownGroups.find(iog->defid->getText());
  if (G == m_KnownGroups.end()) {
    reportError(sourceloc(iog),
      "no known group definition for '%s'",iog->defid->getText().c_str());
  }
  // check io specs
  if (iog->ioList() != nullptr && (iog->INPUT() != nullptr || iog->OUTPUT() != nullptr)) {
    reportError(sourceloc(iog),
      "specify either a detailed io list, or input/output for the entire group");
  }
  // group prefix
  string grpre = iog->groupname->getText();
  m_VIOGroups.insert(make_pair(grpre,G->second));
  // get var list from group
  unordered_map<string,t_var_nfo> vars;
  for (auto v : G->second->varList()->var()) {
    t_var_nfo vnfo;
    std::string is_group;
    gatherVarNfo(v->declarationVar(), vnfo, false, _current, is_group);
    vnfo.srcloc = sourceloc(iog->IDENTIFIER()[1]);
    // sameas?
    if (vnfo.type_nfo.base_type == Parameterized) {
      reportError(sourceloc(v->declarationVar()->IDENTIFIER()),
        "entry '%s': 'sameas' not allowed in group",
        vnfo.name.c_str(), iog->defid->getText().c_str());
    }
    // duplicates?
    if (vars.count(vnfo.name)) {
      reportError(sourceloc(v->declarationVar()->IDENTIFIER()),
        "entry '%s' declared twice in group definition '%s'",
        vnfo.name.c_str(),iog->defid->getText().c_str());
    }
    vars.insert(make_pair(vnfo.name,vnfo));
  }
  // create vars
  if (iog->ioList() != nullptr) {
    for (auto io : iog->ioList()->io()) {
      // -> check for existence
      auto V = vars.find(io->IDENTIFIER()->getText());
      if (V == vars.end()) {
        reportError(sourceloc(io->IDENTIFIER()),
          "'%s' not in group '%s'", io->IDENTIFIER()->getText().c_str(), iog->defid->getText().c_str());
      }
      // add it where it belongs
      if (io->is_input != nullptr) {
        t_inout_nfo inp;
        var_nfo_copy(inp, V->second);
        inp.name = grpre + "_" + V->second.name;
        m_Inputs.emplace_back(inp);
        m_InputNames.insert(make_pair(inp.name, (int)m_Inputs.size() - 1));
      } else if (io->is_inout != nullptr) {
        t_inout_nfo inp;
        var_nfo_copy(inp, V->second);
        inp.name = grpre + "_" + V->second.name;
        m_InOuts.emplace_back(inp);
        m_InOutNames.insert(make_pair(inp.name, (int)m_InOuts.size() - 1));
      } else if (io->is_output != nullptr) {
        t_output_nfo oup;
        var_nfo_copy(oup, V->second);
        oup.name = grpre + "_" + V->second.name;
        oup.combinational         = (io->combinational != nullptr || io->combinational_nocheck != nullptr);
        oup.combinational_nocheck = (io->combinational_nocheck != nullptr);
        m_Outputs.emplace_back(oup);
        m_OutputNames.insert(make_pair(oup.name, (int)m_Outputs.size() - 1));
      }
    }
  } else {
    if (iog->INPUT() != nullptr) {
      // all input
      for (auto v : vars) {
        t_inout_nfo inp;
        var_nfo_copy(inp, v.second);
        inp.name = grpre + "_" + v.second.name;
        m_Inputs.emplace_back(inp);
        m_InputNames.insert(make_pair(inp.name, (int)m_Inputs.size() - 1));
      }
    } else {
      sl_assert(iog->OUTPUT());
      // all output
      for (auto v : vars) {
        t_output_nfo oup;
        var_nfo_copy(oup, v.second);
        oup.name = grpre + "_" + v.second.name;
        oup.combinational         = (iog->combinational != nullptr || iog->combinational_nocheck != nullptr);
        oup.combinational_nocheck = (iog->combinational_nocheck != nullptr);
        m_Outputs.emplace_back(oup);
        m_OutputNames.insert(make_pair(oup.name, (int)m_Outputs.size() - 1));
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::gatherIoInterface(siliceParser::IoDefContext *itrf)
{
  // find interface declaration
  auto I = m_KnownInterfaces.find(itrf->defid->getText());
  if (I == m_KnownInterfaces.end()) {
    reportError(sourceloc(itrf),
      "no known interface definition for '%s'", itrf->defid->getText().c_str());
  }
  // group prefix
  string grpre = itrf->groupname->getText();
  m_VIOGroups.insert(make_pair(grpre, I->second));
  // get member list from interface
  unordered_set<string> vars;
  for (auto io : I->second->ioList()->io()) {
    t_var_nfo vnfo;
    vnfo.name               = io->IDENTIFIER()->getText();
    vnfo.type_nfo.base_type = Parameterized;
    vnfo.type_nfo.width     = 0;
    vnfo.table_size         = 0;
    vnfo.srcloc             = sourceloc(itrf->IDENTIFIER()[1]);
    if (io->declarationVarInitCstr() != nullptr) {
      if (io->declarationVarInitCstr()->value() != nullptr) {
        vnfo.init_values.push_back("0");
        vnfo.init_values[0] = gatherValue(io->declarationVarInitCstr()->value());
      } else {
        if (io->declarationVarInitCstr()->UNINITIALIZED() != nullptr) {
          vnfo.do_not_initialize = true;
        }
      }
      vnfo.init_at_startup = true;
    } else {
      vnfo.do_not_initialize = false;
    }
    if (vars.count(vnfo.name)) {
      reportError(sourceloc(io->IDENTIFIER()),
        "entry '%s' declared twice in interface definition '%s'",
        vnfo.name.c_str(), itrf->defid->getText().c_str());
    }
    vars.insert(vnfo.name);
    // create vars
    if (io->is_input != nullptr) {
      t_inout_nfo inp;
      var_nfo_copy(inp, vnfo);
      inp.name              = grpre + "_" + vnfo.name;
      m_Inputs.emplace_back(inp);
      m_InputNames.insert(make_pair(inp.name, (int)m_Inputs.size() - 1));
      m_Parameterized.push_back(inp.name);
      if (inp.init_at_startup) {
        reportError(sourceloc(io->IDENTIFIER()),
          "input startup initializers have no effect in interface definition,\n         the initialization value comes from the group (member '%s' of '%s')",
          vnfo.name.c_str(), itrf->defid->getText().c_str());
      }
    } else if (io->is_inout != nullptr) {
      t_inout_nfo inp;
      var_nfo_copy(inp, vnfo);
      inp.name              = grpre + "_" + vnfo.name;
      m_InOuts.emplace_back(inp);
      m_InOutNames.insert(make_pair(inp.name, (int)m_InOuts.size() - 1));
      m_Parameterized.push_back(inp.name);
    } else if (io->is_output != nullptr) {
      t_output_nfo oup;
      var_nfo_copy(oup, vnfo);
      oup.name                  = grpre + "_" + vnfo.name;
      oup.combinational         = (io->combinational != nullptr) || (io->combinational_nocheck != nullptr);
      oup.combinational_nocheck = (io->combinational_nocheck != nullptr);
      m_Outputs.emplace_back(oup);
      m_OutputNames.insert(make_pair(oup.name, (int)m_Outputs.size() - 1));
      m_Parameterized.push_back(oup.name);
    }
  }
}

// -------------------------------------------------

void Algorithm::gatherIOs(siliceParser::InOutListContext* inout)
{
  t_combinational_block empty;
  if (inout == nullptr) {
    return;
  }
  // go through io list
  for (auto io : inout->inOrOut()) {
    bool found;
    t_source_loc srcloc = sourceloc(io);
    auto input       = dynamic_cast<siliceParser::InputContext*>   (io->input());
    auto output      = dynamic_cast<siliceParser::OutputContext*>  (io->output());
    auto inout       = dynamic_cast<siliceParser::InoutContext*>   (io->inout());
    auto iodef       = dynamic_cast<siliceParser::IoDefContext*>   (io->ioDef());
    auto allouts     = dynamic_cast<siliceParser::OutputsContext *>(io->outputs());
    if (input) {
      t_inout_nfo io;
      gatherInputNfo(input, io, &empty);
      getVIODefinition(io.name, found);
      if (found) {
        reportError(srcloc, "input '%s': this name is already used by a previous definition", io.name.c_str());
      }
      m_Inputs.emplace_back(io);
      m_InputNames.insert(make_pair(io.name, (int)m_Inputs.size() - 1));
      if (io.type_nfo.base_type == Parameterized) {
        m_Parameterized.push_back(io.name);
      }
    } else if (output) {
      t_output_nfo io;
      gatherOutputNfo(output, io, &empty);
      getVIODefinition(io.name, found);
      if (found) {
        reportError(srcloc, "output '%s': this name is already used by a previous definition", io.name.c_str());
      }
      m_Outputs.emplace_back(io);
      m_OutputNames.insert(make_pair(io.name, (int)m_Outputs.size() - 1));
      if (io.type_nfo.base_type == Parameterized) {
        m_Parameterized.push_back(io.name);
      }
    } else if (inout) {
      t_inout_nfo io;
      gatherInoutNfo(inout, io, &empty);
      getVIODefinition(io.name, found);
      if (found) {
        reportError(srcloc, "inout '%s': this name is already used by a previous definition", io.name.c_str());
      }
      m_InOuts.emplace_back(io);
      m_InOutNames.insert(make_pair(io.name, (int)m_InOuts.size() - 1));
      if (io.type_nfo.base_type == Parameterized) {
        m_Parameterized.push_back(io.name);
      }
    } else if (iodef) {
      gatherIoDef(iodef, &empty);
    } else if (allouts) {
      reportError(srcloc,"'outputs' is no longer supported (here used on '%s')", allouts->alg->getText().c_str());
    } else {
      // symbol, ignore
    }
  }
}

// -------------------------------------------------

/// \brief returns the postfix of an identifier knwon to be a group member
static std::string memberPostfix(std::string name)
{
  auto pos = name.rfind('_');
  if (pos != std::string::npos) {
    return name.substr(pos + 1);
  } else {
    return "";
  }
}

/// \brief returns the prefix of an identifier knwon to be a group member
static std::string memberPrefix(std::string name)
{
  auto pos = name.rfind('_');
  if (pos != std::string::npos) {
    return name.substr(0,pos);
  } else {
    return "";
  }
}

// -------------------------------------------------

void Algorithm::getCallParams(
  siliceParser::CallParamListContext    *params,
  std::vector<t_call_param>&            _inparams,
  const t_combinational_block_context   *bctx
) const
{
  if (params == nullptr) {
    return;
  }
  for (auto param : params->expression_0()) {
    t_call_param nfo;
    nfo.expression = param;
    std::string identifier;
    if (isIdentifier(nfo.expression, identifier)) {
      // check if that is a group, if yes store its definition
      identifier = translateVIOName(identifier, bctx);
      auto G = m_VIOGroups.find(identifier);
      if (G != m_VIOGroups.end()) {
        nfo.what = &G->second;
      } else {
        nfo.what = identifier;
      }
    } else {
      siliceParser::AccessContext *access = nullptr;
      if (isAccess(nfo.expression, access)) {
        nfo.what = access;
      }
    }
    _inparams.push_back(nfo);
  }
}

// -------------------------------------------------

bool Algorithm::matchCallParams(
  const std::vector<t_call_param>&     given_params,
  const std::vector<std::string>&      expected_params,
  const t_combinational_block_context* bctx,
  std::vector<t_call_param>&          _matches) const
{
  if (given_params.empty() && expected_params.empty()) {
    return true;  // both empty, success!
  }
  if (given_params.empty() || expected_params.empty()) {
    return false; // only one empty, cannot match
  }
  int g = 0; // current in given params
  int i = 0; // current in input params
  while (i < expected_params.size()) {
    if (g >= given_params.size()) {
      return false; // partial match
    }
    if (std::holds_alternative<const t_group_definition *>(given_params[g].what)) { // given param is a group
      // get the base identifier
      std::string base;
      bool ok = isIdentifier(given_params[g].expression, base);
      sl_assert(ok);
      base = translateVIOName(base, bctx);
      bool no_match = true;
      // check if a member matches
      for (auto member : getGroupMembers(*std::get<const t_group_definition *>(given_params[g].what))) {
        if (memberPostfix(expected_params[i]) == member) {
          // match with the identifier
          t_call_param matched;
          matched.expression = given_params[g].expression;
          matched.what       = base + "_" + member;
          _matches.push_back(matched);
          no_match = false;
          ++i; // advance on i only
          break;
        }
      }
      if (no_match) {
        ++g; // advance on g only
      }
    } else {
      t_call_param matched;
      _matches.push_back(given_params[g]);
      ++i;
      ++g;
    }
  }
  if (g == given_params.size()) {
    // exact match
    return true;
  } else if (g + 1 == given_params.size()) {
    // we did not use the last entire group, that is ok
    return std::holds_alternative<const t_group_definition *>(given_params[g].what);
  } else {
    // improper match
    return false;
  }
}

// -------------------------------------------------

void Algorithm::parseCallParams(
  siliceParser::CallParamListContext *params,
  const Algorithm *alg,
  bool input_else_output,
  const t_combinational_block_context *bctx,
  std::vector<t_call_param> &_matches) const
{
  std::vector<t_call_param> given_params;
  getCallParams(params, given_params, bctx);
  std::vector<std::string> expected_params;
  if (input_else_output) {
    for (auto I : alg->inputs()) {
      expected_params.push_back(I.name);
    }
  } else {
    for (auto O : alg->outputs()) {
      expected_params.push_back(O.name);
    }
  }
  bool ok = matchCallParams(given_params, expected_params, bctx, _matches);
  if (!ok) {
    reportError(sourceloc(params),
      "incorrect number of %s parameters in call to algorithm '%s'",
      input_else_output ? "input" : "output", alg->m_Name.c_str());
  }
  sl_assert(_matches.size() == expected_params.size());
}

// -------------------------------------------------

void Algorithm::parseCallParams(
  siliceParser::CallParamListContext *params,
  const t_subroutine_nfo *sub,
  bool input_else_output,
  const t_combinational_block_context *bctx,
  std::vector<t_call_param> &_matches) const
{
  std::vector<t_call_param> given_params;
  getCallParams(params, given_params, bctx);
  std::vector<std::string> expected_params;
  if (input_else_output) {
    expected_params = sub->inputs;
  } else {
    expected_params = sub->outputs;
  }
  bool ok = matchCallParams(given_params, expected_params, bctx, _matches);
  if (!ok) {
    reportError(sourceloc(params),
      "incorrect %s parameters in call to algorithm '%s', last correct match was parameter '%s'",
      input_else_output ? "input" : "output", sub->name.c_str(),
      (_matches.size() - 1) >= expected_params.size() ? "" : expected_params[_matches.size() - 1].c_str());
  }
  if (input_else_output) {
    sl_assert(_matches.size() == sub->inputs.size());
  } else {
    sl_assert(_matches.size() == sub->outputs.size());
  }
}

// -------------------------------------------------

Algorithm::t_combinational_block *Algorithm::gather(
  antlr4::tree::ParseTree *tree,
  t_combinational_block   *_current,
  t_gather_context        *_context)
{
  if (tree == nullptr) {
    return _current;
  }

  if (_current->srcloc.interval == antlr4::misc::Interval::INVALID) {
    _current->srcloc = sourceloc(tree);
  }

  auto algbody      = dynamic_cast<siliceParser::DeclAndInstrListContext*>(tree);
  auto unitbody     = dynamic_cast<siliceParser::UnitBlocksContext*>(tree);
  auto algblock     = dynamic_cast<siliceParser::AlgorithmBlockContext*>(tree);
  auto algcontent   = dynamic_cast<siliceParser::AlgorithmBlockContentContext*>(tree);
  auto decl         = dynamic_cast<siliceParser::DeclarationContext*>(tree);
  auto ilist        = dynamic_cast<siliceParser::InstructionListContext*>(tree);
  auto ifelse       = dynamic_cast<siliceParser::IfThenElseContext*>(tree);
  auto ifthen       = dynamic_cast<siliceParser::IfThenContext*>(tree);
  auto switchC      = dynamic_cast<siliceParser::SwitchCaseContext*>(tree);
  auto loop         = dynamic_cast<siliceParser::WhileLoopContext*>(tree);
  auto jump         = dynamic_cast<siliceParser::JumpContext*>(tree);
  auto assign       = dynamic_cast<siliceParser::AssignmentContext*>(tree);
  auto display      = dynamic_cast<siliceParser::DisplayContext *>(tree);
  auto inline_v     = dynamic_cast<siliceParser::Inline_vContext *>(tree);
  auto finish       = dynamic_cast<siliceParser::FinishContext *>(tree);
  auto async        = dynamic_cast<siliceParser::AsyncExecContext*>(tree);
  auto join         = dynamic_cast<siliceParser::JoinExecContext*>(tree);
  auto sync         = dynamic_cast<siliceParser::SyncExecContext*>(tree);
  auto circinst     = dynamic_cast<siliceParser::CircuitryInstContext*>(tree);
  auto repeat       = dynamic_cast<siliceParser::RepeatBlockContext*>(tree);
  auto pip          = dynamic_cast<siliceParser::PipelineContext*>(tree);
  auto ret          = dynamic_cast<siliceParser::ReturnFromContext*>(tree);
  auto breakL       = dynamic_cast<siliceParser::BreakLoopContext*>(tree);
  auto block        = dynamic_cast<siliceParser::BlockContext *>(tree);
  auto assert_      = dynamic_cast<siliceParser::Assert_Context *>(tree);
  auto assume       = dynamic_cast<siliceParser::AssumeContext *>(tree);
  auto restrict     = dynamic_cast<siliceParser::RestrictContext *>(tree);
  auto was_at       = dynamic_cast<siliceParser::Was_atContext *>(tree);
  auto assertstable = dynamic_cast<siliceParser::AssertstableContext *>(tree);
  auto assumestable = dynamic_cast<siliceParser::AssumestableContext *>(tree);
  auto cover        = dynamic_cast<siliceParser::CoverContext *>(tree);

  bool recurse  = true;

  if (algbody) {
    // gather declarations
    for (auto d : algbody->declaration()) {
      gatherDeclaration(dynamic_cast<siliceParser::DeclarationContext *>(d), _current, false);
    }
    // add global subroutines now (reparse them as if defined in this algorithm)
    for (const auto &s : m_KnownSubroutines) {
      gatherSubroutine(s.second, _current, _context);
    }
    // gather local subroutines
    for (auto s : algbody->subroutine()) {
      gatherSubroutine(dynamic_cast<siliceParser::SubroutineContext *>(s), _current, _context);
    }
    // gather stableinput checks
    for (auto s : algbody->stableinput()) {
      gatherStableinputCheck(s, _current, _context);
    }
    // gather always assigned
    gatherAlwaysAssigned(algbody->alwaysPre, &m_AlwaysPre);
    m_AlwaysPre.srcloc = sourceloc(algbody->alwaysPre);
    m_AlwaysPre.context.parent_scope = _current;
    // gather always block if defined
    if (algbody->alwaysBlock() != nullptr
      && algbody->alwaysBeforeBlock() != nullptr) {
      reportError(sourceloc(algbody->alwaysBlock()->ALWAYS()),
        "Use either an always_before or an always block, not both. They are synonym in this context.");
    }
    if (algbody->alwaysBlock() != nullptr) {
      gather(algbody->alwaysBlock(), &m_AlwaysPre, _context);
      if (!isStateLessGraph(&m_AlwaysPre)) {
        reportError(sourceloc(algbody->alwaysBlock()->ALWAYS()),
          "always block can only be a one-cycle block");
      }
    }
    if (algbody->alwaysBeforeBlock() != nullptr) {
      gather(algbody->alwaysBeforeBlock(), &m_AlwaysPre, _context);
      if (!isStateLessGraph(&m_AlwaysPre)) {
        reportError(sourceloc(algbody->alwaysBeforeBlock()->ALWAYS_BEFORE()),
          "always_before block can only be a one-cycle block");
      }
    }
    m_AlwaysPost.context.parent_scope = _current;
    if (algbody->alwaysAfterBlock() != nullptr) {
      gather(algbody->alwaysAfterBlock(), &m_AlwaysPost, _context);
      m_AlwaysPost.srcloc = sourceloc(algbody->alwaysAfterBlock());
      if (!isStateLessGraph(&m_AlwaysPost)) {
        reportError(sourceloc(algbody->alwaysAfterBlock()->ALWAYS_AFTER()),
          "always_after block can only be a one-cycle block");
      }
      if (algbody->alwaysBlock() != nullptr) {
        warn(Deprecation, sourceloc(algbody->alwaysBlock()),
          "Use 'always_before' instead of 'always' in conjunction with 'always_after'");
      }
    }
    // deprecation on algorithms with always blocks
    if ( algbody->alwaysBlock() != nullptr
      || algbody->alwaysBeforeBlock() != nullptr
      || algbody->alwaysAfterBlock() != nullptr) {
      warn(Deprecation, sourceloc(algbody),
        "Use a 'unit' instead of always blocks in an algorithm.");
    }
    // recurse on instruction list
    _current->srcloc = sourceloc(algbody->instructionList());
    _current = gather(algbody->instructionList(), _current, _context);
    recurse  = false;
  } else if (unitbody)     {
    // gather declarations
    for (auto d : unitbody->declaration()) {
      gatherDeclaration(dynamic_cast<siliceParser::DeclarationContext *>(d), _current, false);
    }
    // gather stableinput checks
    for (auto s : unitbody->stableinput()) {
      gatherStableinputCheck(s, _current, _context);
    }
    // gather always assigned
    gatherAlwaysAssigned(unitbody->alwaysPre, &m_AlwaysPre);
    m_AlwaysPre.srcloc = sourceloc(unitbody->alwaysPre);
    m_AlwaysPre.context.parent_scope = _current;
    m_AlwaysPost.context.parent_scope = _current;
    // gather always block if defined
    if (unitbody->alwaysBlock() != nullptr) {
      if (unitbody->alwaysBeforeBlock() != nullptr
      || unitbody->algorithmBlock() != nullptr
      || unitbody->alwaysAfterBlock() != nullptr) {
      reportError(sourceloc(unitbody->alwaysBlock()->ALWAYS()),
        "Use either always_before/algorithm/always_after or a single always block.");
      }
      gather(unitbody->alwaysBlock(), &m_AlwaysPre, _context);
      if (!isStateLessGraph(&m_AlwaysPre)) {
        reportError(sourceloc(unitbody->alwaysBlock()->ALWAYS()),
          "always block can only be a one-cycle block");
      }
    } else {
      // always before?
      if (unitbody->alwaysBeforeBlock() != nullptr) {
        gather(unitbody->alwaysBeforeBlock(), &m_AlwaysPre, _context);
        if (!isStateLessGraph(&m_AlwaysPre)) {
          reportError(sourceloc(unitbody->alwaysBeforeBlock()->ALWAYS_BEFORE()),
            "always_before block can only be a one-cycle block");
        }
      }
      // always after?
      if (unitbody->alwaysAfterBlock() != nullptr) {
        gather(unitbody->alwaysAfterBlock(), &m_AlwaysPost, _context);
        m_AlwaysPost.srcloc = sourceloc(unitbody->alwaysAfterBlock());
        if (!isStateLessGraph(&m_AlwaysPost)) {
          reportError(sourceloc(unitbody->alwaysAfterBlock()->ALWAYS_AFTER()),
            "always_after block can only be a one-cycle block");
        }
      }
      // algorithm?
      if (unitbody->algorithmBlock() != nullptr) {
        _current->srcloc = sourceloc(unitbody->algorithmBlock());
        _current = gather(unitbody->algorithmBlock(), _current, _context);
      }
    }
    recurse  = false;
  } else if (algblock)     {
    // unit algorithm block
    if (algblock->bpModifiers()) {
      for (auto m : algblock->bpModifiers()->bpModifier()) {
        if (m->sautorun() != nullptr) {
          m_AutoRun = true;
        } else if (m->sonehot() != nullptr) {
          m_OneHot = true;
        } else {
          reportError(sourceloc(m),
            "Modifier is not applicable on a unit algorithm block, apply it to the parent unit.");
        }
      }
    }
    // gather algorithm content
    _current->srcloc = sourceloc(algblock);
    _current = gather(algblock->algorithmBlockContent(), _current, _context);
    recurse  = false;
  } else if (algcontent)   {
    // add global subroutines now (reparse them as if defined in this algorithm)
    for (const auto &s : m_KnownSubroutines) {
      gatherSubroutine(s.second, _current, _context);
    }
    // make a new block for the algorithm
    t_combinational_block *newblock = addBlock(generateBlockName(), _current, nullptr, sourceloc(algcontent));
    _current->next(newblock);
    // gather declarations
    for (auto d : algcontent->declaration()) {
      gatherDeclaration(dynamic_cast<siliceParser::DeclarationContext *>(d), newblock, false);
    }
    // gather local subroutines
    for (auto s : algcontent->subroutine()) {
      gatherSubroutine(dynamic_cast<siliceParser::SubroutineContext *>(s), newblock, _context);
    }
    // gather instructions
    t_combinational_block *after     = gather(algcontent->instructionList(), newblock, _context);
    // produce next block
    t_combinational_block *nextblock = addBlock(generateBlockName(), _current, nullptr, sourceloc(algcontent));
    after->next(nextblock);
    // set next block as current
    _current = nextblock;
    // recurse on instruction list
    recurse  = false;
  } else if (decl)         { gatherDeclaration(decl, _current, true);                      recurse = false;
  } else if (ifelse)       { _current = gatherIfElse(ifelse, _current, _context);          recurse = false;
  } else if (ifthen)       { _current = gatherIfThen(ifthen, _current, _context);          recurse = false;
  } else if (switchC)      { _current = gatherSwitchCase(switchC, _current, _context);     recurse = false;
  } else if (loop)         { _current = gatherWhile(loop, _current, _context);             recurse = false;
  } else if (repeat)       { _current = gatherRepeatBlock(repeat, _current, _context);     recurse = false;
  } else if (pip)          { _current = gatherPipeline(pip, _current, _context);           recurse = false;
  } else if (sync)         { _current = gatherSyncExec(sync, _current, _context);          recurse = false;
  } else if (join)         { _current = gatherJoinExec(join, _current, _context);          recurse = false;
  } else if (circinst)     { _current = gatherCircuitryInst(circinst, _current, _context); recurse = false;
  } else if (jump)         { _current = gatherJump(jump, _current, _context);              recurse = false;
  } else if (ret)          { _current = gatherReturnFrom(ret, _current, _context);         recurse = false;
  } else if (breakL)       { _current = gatherBreakLoop(breakL, _current, _context);       recurse = false;
  } else if (async)        { _current->instructions.push_back(t_instr_nfo(async, _current, _context->__id));    recurse = false;
  } else if (assign)       { _current->instructions.push_back(t_instr_nfo(assign, _current, _context->__id));   recurse = false;
  } else if (display)      { _current->instructions.push_back(t_instr_nfo(display, _current, _context->__id));  recurse = false;
  } else if (inline_v)     { _current->instructions.push_back(t_instr_nfo(inline_v, _current, _context->__id)); recurse = false;
  } else if (finish)       { _current->instructions.push_back(t_instr_nfo(finish, _current, _context->__id));   recurse = false;
  } else if (assert_)      { _current->instructions.push_back(t_instr_nfo(assert_, _current, _context->__id));  recurse = false;
  } else if (assume)       { _current->instructions.push_back(t_instr_nfo(assume, _current, _context->__id));   recurse = false;
  } else if (restrict)     { _current->instructions.push_back(t_instr_nfo(restrict, _current, _context->__id)); recurse = false;
  } else if (cover)        { _current->instructions.push_back(t_instr_nfo(cover, _current, _context->__id));    recurse = false;
  } else if (was_at)       { gatherPastCheck(was_at, _current, _context);                  recurse = false;
  } else if (assertstable) { gatherStableCheck(assertstable, _current, _context);          recurse = false;
  } else if (assumestable) { gatherStableCheck(assumestable, _current, _context);          recurse = false;
  } else if (block)        { _current = gatherBlock(block, _current, _context);            recurse = false;
  } else if (ilist)        { _current = splitOrContinueBlock(ilist, _current, _context); }

  // recurse
  if (recurse) {
    for (const auto& c : tree->children) {
      _current = gather(c, _current, _context);
    }
  }

  return _current;
}

// -------------------------------------------------

void Algorithm::resolveForwardJumpRefs()
{
  for (auto& refs : m_JumpForwardRefs) {
    // get block by name
    auto B = m_State2Block.find(refs.first);
    if (B == m_State2Block.end()) {
      std::string lines;
      sl_assert(!refs.second.empty());
      for (const auto& j : refs.second) {
        lines += std::to_string(j.jump->getStart()->getLine()) + ",";
      }
      lines.pop_back(); // remove last comma
      std::string msg = "cannot find state '"
        + refs.first + "' (line"
        + (refs.second.size() > 1 ? "s " : " ")
        + lines + ")";
      reportError(sourceloc(refs.second.front().jump),
        "%s", msg.c_str());
    } else {
      for (auto& j : refs.second) {
        if (dynamic_cast<siliceParser::JumpContext*>(j.jump)) {
          // update jump
          j.from->next(B->second);
        } else {
          sl_assert(false);
        }
        B->second->is_state = true; // destination has to be a state
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::generateStates()
{
  // generate state ids and determine sub-state chains
  m_MaxState = 0;
  std::unordered_set< t_combinational_block * > visited;
  std::queue< t_combinational_block * > q;
  q.push(m_Blocks.front()); // start from main
  while (!q.empty()) {
    auto cur = q.front();
    q.pop();
    // generate a state if needed
    if (cur->is_state) {
      sl_assert(cur->state_id == -1);
      cur->state_id = m_MaxState++;
      cur->parent_state_id = cur->state_id;
      // potential sub-state chain root?
      if (cur->next()) {
        // explore sub-state chain
        int num_sub_states = 0;
        t_combinational_block *lcur = cur;
        while (lcur) {
          lcur->sub_state_id = num_sub_states++;
          if (lcur != cur) {
            sl_assert(lcur->state_id == -1);
            lcur->is_state = false;
            lcur->is_sub_state = true;
          }
          std::set<t_combinational_block*> leaves;
          findNonCombinationalLeaves(lcur, leaves);
          if (leaves.size() == 1) {
            // grow sequence
            lcur = *leaves.begin();
            if (!lcur->could_be_sub) {
              // but requires a true state
              sl_assert(lcur->is_state);
              break;
            }
          } else {
            // the remainder is not a sequence
            break;
          }
        }
        if (num_sub_states > 1) {
          cur->num_sub_states = num_sub_states;
          std::cerr << "block " << cur->block_name << " has " << num_sub_states << " sub states" << nxl;
        }
      }
    }
    // recurse
    std::vector< t_combinational_block * > children;
    cur->getChildren(children);
    for (auto c : children) {
      if (c->is_state) {
        // NOTE: anyone sees a good way to get rid of the const cast? (without rewriting fastForward)
        c = const_cast<t_combinational_block *>(fastForward(c));
      }
      if (visited.find(c) == visited.end()) {
        c->parent_state_id = cur->parent_state_id;
        sl_assert(c->parent_state_id > -1);
        visited.insert(c);
        q.push(c);
      }
    }
  }
  // additional internal state
  m_MaxState++;
  // report
  std::cerr << "algorithm " << m_Name
    << " num states: " << m_MaxState;
  if (hasNoFSM()) {
    std::cerr << " (no FSM)";
  }
  if (!requiresReset()) {
    std::cerr << " (no reset)";
  }
  if (doesNotCallSubroutines()) {
    std::cerr << " (no subs)";
  }
  std::cerr << nxl;
}

// -------------------------------------------------

int Algorithm::maxState() const
{
  return m_MaxState;
}

// -------------------------------------------------

int Algorithm::entryState() const
{
  /// TODO: fastforward, but not so simple, can lead to trouble with var inits,
  // for instance if the entry state becomes the first in a loop
  // fastForward(m_Blocks.front())->state_id
  return 0;
}

// -------------------------------------------------

int Algorithm::terminationState() const
{
  return m_MaxState - 1;
}

// -------------------------------------------------

int  Algorithm::toFSMState(int state) const
{
  if (!m_OneHot) {
    return state;
  } else {
    return 1 << state;
  }
}

// -------------------------------------------------

int Algorithm::width(int val) const
{
  sl_assert(val > 0);
  if (val == 1) return 1;
  int w = 0;
  while (val > (1 << w)) {
    w++;
  }
  return w;
}

// -------------------------------------------------

int Algorithm::stateWidth() const
{
  return width(maxState());
}

// -------------------------------------------------

const Algorithm::t_combinational_block *Algorithm::fastForward(const t_combinational_block *block) const
{
  sl_assert(block->is_state);
  const t_combinational_block *current = block;
  if (current->no_skip) {
    // no skip, stop here
    return current;
  }
  const t_combinational_block *last_state = block;
  while (true) {
    if (!current->instructions.empty()) {
      bool stop = true;
      if (current->instructions.size() == 1) {
        // special case of empty return from call
        auto j = dynamic_cast<siliceParser::JoinExecContext *>(current->instructions.front().instr);
        if (j != nullptr) {
          // find algorithm
          auto A = m_InstancedBlueprints.find(j->IDENTIFIER()->getText());
          if (A == m_InstancedBlueprints.end()) {
            // return of subroutine?
            auto S = m_Subroutines.find(j->IDENTIFIER()->getText());
            if (S == m_Subroutines.end()) {
              reportError(sourceloc(j),"unknown identifier '%s'", j->IDENTIFIER()->getText().c_str());
            }
            if (S->second->outputs.empty()) {
              stop = false; // nothing returned, we can fast forward
            }
          } else {
            sl_assert(dynamic_cast<Algorithm*>(A->second.blueprint.raw()) != nullptr); // calls should not be allowed on anything else
            if (A->second.blueprint->outputs().empty()) {
              stop = false; // nothing returned, we can fast forward
            }
          }
        }
      }
      // non-empty, stop here
      if (stop) {
        return last_state;
      }
    }
    if (current->next() == nullptr) {
      // not a simple jump, stop here
      return last_state;
    } else {
      current = current->next()->next;
    }
    if (current->no_skip) {
      // no skip, stop here
      return last_state;
    }
    if (current->is_state) {
      last_state = current;
    }
  }
  // never reached
  return nullptr;
}

// -------------------------------------------------

bool Algorithm::hasNoFSM() const
{
  if (!m_Blocks.front()->instructions.empty()) {
    return false;
  }
  if (m_Blocks.front()->end_action != nullptr) {
    return false;
  }
  for (const auto &b : m_Blocks) { // NOTE: no need to consider m_AlwaysPre, it has to be combinational
    if (b->state_id == -1 && b->is_state) {
      continue; // block is never reached
    }
    if (b->state_id > 0) { // block has a stateid
      return false;
    }
  }
  return true;
}

// -------------------------------------------------

bool Algorithm::doesNotCallSubroutines() const
{
  if (hasNoFSM()) {
    return true;
  }
  // now we check whether there are subroutine calls
  for (const auto &b : m_Blocks) { // NOTE: no need to consider m_AlwaysPre, it has to be comibinational
    if (b->state_id == -1 && b->is_state) {
      continue; // block is never reached
    }
    // contains a suborutine call?
    for (auto i : b->instructions) {
      auto call = dynamic_cast<siliceParser::SyncExecContext*>(i.instr);
      if (call) {
        // find algorithm / subroutine
        auto A = m_InstancedBlueprints.find(call->joinExec()->IDENTIFIER()->getText());
        if (A == m_InstancedBlueprints.end()) { // not a call to algorithm?
          auto S = m_Subroutines.find(call->joinExec()->IDENTIFIER()->getText());
          if (S != m_Subroutines.end()) { // nested call to subroutine
            return false;
          }
        }
      }
    }
  }
  return true;
}

// -------------------------------------------------

bool Algorithm::requiresReset() const
{
  // has an FSM?
  if (!hasNoFSM()) {
    return true;
  }
  // has var or outputs with init?
  for (const auto &v : m_Vars) {
    if (v.usage != e_FlipFlop) continue;
    if (!v.do_not_initialize) {
      return true;
    }
  }
  for (const auto &v : m_Outputs) {
    if (v.usage != e_FlipFlop) continue;
    if (!v.do_not_initialize) {
      return true;
    }
  }
  // do any of the instantiated blueprints require a reset?
  for (const auto &I : m_InstancedBlueprints) {
    if (I.second.blueprint->requiresReset()) {
      return true;
    }
  }
  return false;
}

// -------------------------------------------------

bool Algorithm::isNotCallable() const
{
  if (hasNoFSM()) {
    return true;
  } else if (m_AutoRun) {
    return true;
  }
  return false; // this algorithm has to be called
}

// -------------------------------------------------

void Algorithm::dependencyClosure(t_vio_dependencies& _depds) const
{
  bool changed = true;
  while (changed) {
    changed = false;
    set<std::string> written;
    for (auto &d : _depds.dependencies) {
      written.insert(d.first);
    }
    for (const auto& w : written) {
      auto dw = _depds.dependencies.at(w); // copy
      // for each of the variable w depends on
      for (const auto &d : _depds.dependencies.at(w)) {
        if (_depds.dependencies.count(d) != 0) {
          for (const auto &d2 : _depds.dependencies.at(d)) {
            // add their own dependences to w
            if (dw.count(d2) == 0) {
              dw.insert(d2);
              changed = true;
            }
          }
        }
      }
      _depds.dependencies.at(w) = dw;
    }
  }
}

// -------------------------------------------------

void Algorithm::updateAndCheckDependencies(t_vio_dependencies& _depds, antlr4::tree::ParseTree* instr, const t_combinational_block_context *bctx) const
{
  if (instr == nullptr) {
    return;
  }
  // determine VIOs accesses for instruction
  std::unordered_set<std::string> read;
  std::unordered_set<std::string> written;
  determineVIOAccess(instr, m_VarNames, bctx, read, written);
  determineVIOAccess(instr, m_InputNames, bctx, read, written);
  determineVIOAccess(instr, m_OutputNames, bctx, read, written);
  // update and check
  updateAndCheckDependencies(_depds, sourceloc(dynamic_cast<antlr4::ParserRuleContext *>(instr)), read, written, bctx);
}

// -------------------------------------------------

void Algorithm::updateAndCheckDependencies(t_vio_dependencies & _depds, const t_source_loc& sloc, const std::unordered_set<std::string> & read, const std::unordered_set<std::string> & written, const t_combinational_block_context * bctx) const
{
  // record which vars were written before
  std::unordered_set<std::string> written_before;
  for (const auto &d : _depds.dependencies) {
    written_before.insert(d.first);
  }
  // update written vars dependencies
  std::unordered_set<std::string> all_read;
  for (const auto& r : read) {
    // insert r in dependencies
    all_read.insert(r);
  }
  // update dependencies of written vars
  /// NOTE: a current limitation is the we might miss dependencies on partial writes
  for (const auto& w : written) {
    _depds.dependencies[w] = all_read;
  }
  // depedency closure
  dependencyClosure(_depds);

  /// DEBUG
  if (0) {
    std::cerr << "---- " << "written: ";
    for (auto w : written) {
      std::cerr << w << ' ';
    }
    std::cerr << nxl;
    for (auto w : _depds.dependencies) {
      std::cerr << "var " << w.first << " depds on ";
      for (auto r : w.second) {
        std::cerr << r << ' ';
      }
      std::cerr << nxl;
    }
    std::cerr << nxl;
  }

  // check if everything is legit
  // for each written variable
  for (const auto& w : written) {
    // yes: does it depend on itself?
    const auto& d = _depds.dependencies.at(w);
    if (d.count(w) > 0) {
      // check if the variable was written before and depends on self
      if (written_before.count(w) > 0) {
        // yes: this would produce a combinational cycle, error!
        string msg = "variable assignement leads to a combinational cycle (variable: '%s')\n\n";
        if (bctx == &m_AlwaysPost.context) { // checks whether in always_after
          msg += "Variables written in always_after can only be initialized at powerup.\nExample: 'uint8 v(0);' in place of 'uint8 v=0;'";
        } else {
          msg += "Consider inserting a sequential split with '++:'";
        }
        reportError(sloc,msg.c_str(), w.c_str());
      }
      // check if any one of the combinational outputs the var depends on, depends on this same var (cycle!)
      for (auto other : d) {
        if (other == w) continue; // skip self
        // find out if other is a combinational output dot syntax
        for (const auto &bp : m_InstancedBlueprints) {
          for (auto os : bp.second.blueprint->outputs()) {
            if (os.combinational && !os.combinational_nocheck) {
              string vname = bp.second.instance_prefix + "_" + os.name;
              if (other == vname) {
                auto F = _depds.dependencies.find(vname);
                if (F != _depds.dependencies.end()) {
                  if (F->second.count(w)) {
                    // yes: this would produce a combinational cycle, error!
                    string msg = "variable assignement leads to a combinational cycle through instantiated unit (variable: '%s')\n\n";
                    reportError(sloc, msg.c_str(), w.c_str());
                  }
                }
              }
            }
          }
        }
        // find out if other is bound to a combinational output
        if (m_VIOBoundToBlueprintOutputs.count(other) > 0) {
          // bound to output, but is this a combinational output?
          for (const auto &bp : m_InstancedBlueprints) {
            bool found = false;
            const auto &bnd = findBindingRight(other, bp.second.bindings, found);
            if (found && bnd.dir == e_Right) {
              if (bp.second.blueprint->output(bnd.left).combinational
                && !bp.second.blueprint->output(bnd.left).combinational_nocheck) {
                string msg = "variable assignement leads to a combinational cycle through instantiated unit (variable: '%s')\n\n";
                reportError(sloc, msg.c_str(), w.c_str());
              }
            }
          }

        }
      }
    }
    // check if the variable depends on a wire, that depends on the variable itself
    for (const auto &d : _depds.dependencies.at(w)) {
      if (_depds.dependencies.count(d) > 0) { // is this dependency also dependent on other vars?
        if (m_VarNames.count(d) > 0) { // yes, is it a variable?
          if (m_Vars.at(m_VarNames.at(d)).usage == e_Wire) { // is it a wire?
            if (_depds.dependencies.at(d).count(w)) { // depends on written var?
              // yes: this would produce a combinational cycle, error!
              reportError(sloc,
                "variable assignement leads to a combinational cycle through variable bound to expression\n\n(variable: '%s', through '%s').",
                w.c_str(), d.c_str());
            }
          }
        }
      }
    }
    // check if the variable is a dependency of a wire that has been assigned before
    // -> find wires that depend on this variable
    for (const auto &a : m_WireAssignments) {
      auto alw = dynamic_cast<siliceParser::AlwaysAssignedContext *>(a.second.instr);
      sl_assert(alw != nullptr);
      sl_assert(alw->IDENTIFIER() != nullptr);
      // -> determine assigned var
      string wire = translateVIOName(alw->IDENTIFIER()->getText(), &a.second.block->context);
      // -> does it depend on written var?
      if (_depds.dependencies.count(wire) > 0) {
        if (_depds.dependencies.at(wire).count(w) > 0) {
          // std::cerr << "wire " << wire << " depends on written " << w << nxl;
          // yes, check if any other variable depends on this wire
          for (const auto &d : _depds.dependencies) {
            if (d.second.count(wire) > 0) {
              // yes, but maybe that's another wire (which is ok)
              bool wire_assign = false;
              if (m_VarNames.count(wire) > 0) {
                wire_assign = (m_Vars.at(m_VarNames.at(wire)).usage == e_Wire);
              }
              if (!wire_assign) {
                // no: leads to problematic case (ambiguity in final value), error!
                reportError(sloc,
                  "variable assignement changes the value of a <: tracked expression that was assigned before\n\n(variable: '%s', through tracker '%s' assigned before to '%s').",
                  w.c_str(), wire.c_str(), d.first.c_str());
              }
            }
          }
        }
      }
    }
  }

}

// -------------------------------------------------

void Algorithm::mergeDependenciesInto(const t_vio_dependencies& _depds0, t_vio_dependencies& _depds) const
{
  for (const auto& d : _depds0.dependencies) {
    _depds.dependencies.insert(d);
  }
}

// -------------------------------------------------

void Algorithm::updateFFUsage(e_FFUsage usage, bool read_access, e_FFUsage &_ff) const
{
  if (usage & e_Q) {
    _ff = (e_FFUsage)((int)_ff | (e_Q));
  }
  if (usage & e_D) {
    if (read_access) {
      if (_ff & e_Latch) {
        _ff = (e_FFUsage)((int)_ff | (e_Q));
      }
    }
    _ff = (e_FFUsage)((int)_ff | (e_D));
  }
  if (usage & e_Latch) {
    _ff = (e_FFUsage)((int)_ff | (e_Latch));
  }
}

// -------------------------------------------------

void Algorithm::clearNoLatchFFUsage(t_vio_ff_usage &_ff) const
{
  for (auto& v : _ff.ff_usage) {
    v.second = (e_FFUsage)((int)v.second & (~e_NoLatch));
  }
}

// -------------------------------------------------

void Algorithm::combineFFUsageInto(const t_combinational_block *debug_block, const t_vio_ff_usage &ff_before, std::vector<t_vio_ff_usage> &ff_branches, t_vio_ff_usage& _ff_after) const
{
  t_vio_ff_usage ff_after; // do not manipulate _ff_after as it is typically a ref to ff_before as well

  // find if some vars are e_D *only* in all branches
  set<string> d_in_all;
  bool first = true;
  for (const auto& br : ff_branches) {
    set<string> d_in_br;
    for (auto& v : br.ff_usage) {
      if (v.second == e_D || v.second == (e_D | e_NoLatch)) { // exactly D (not Q, not latched next)
        d_in_br.insert(v.first);
      }
    }
    if (first) {
      d_in_all = d_in_br;
      first = false;
    } else {
      set<string> tmp;
      set_intersection(
        d_in_all.begin(), d_in_all.end(),
        d_in_br.begin(), d_in_br.end(),
        std::inserter(tmp, tmp.begin()));
      d_in_all = tmp;
    }
    if (d_in_all.empty()) { // no need to continue
      break;
    }
  }
  // all vars that are Q or D in before or branches will be Q or D after
  for (auto& v : ff_before.ff_usage) {
    if (v.second & e_Q) {
      ff_after.ff_usage[v.first] = (e_FFUsage)((int)ff_after.ff_usage[v.first] | e_Q);
    }
    if (v.second & e_D) {
      ff_after.ff_usage[v.first] = (e_FFUsage)((int)ff_after.ff_usage[v.first] | e_D);
    }
  }
  for (const auto& br : ff_branches) {
    for (auto& v : br.ff_usage) {
      if (v.second & e_Q) {
        ff_after.ff_usage[v.first] = (e_FFUsage)((int)ff_after.ff_usage[v.first] | e_Q);
      }
      if (v.second & e_D) {
        ff_after.ff_usage[v.first] = (e_FFUsage)((int)ff_after.ff_usage[v.first] | e_D);
      }
    }
  }
  // all vars in d_in_all loose e_Latch and gain e_NoLatch for the current combinational state
  // since they are /all/ written, there is no need to latch them anymore
  for (auto v : d_in_all) {
    ff_after.ff_usage[v] = (e_FFUsage)(((int)ff_after.ff_usage[v] & (~e_Latch)) | e_NoLatch);
  }
  // the questions that remain are:
  // 1) which vars have to be promoted from D to Q?
  // => all vars that are not Q in branches, but were marked latched before
  for (const auto& br : ff_branches) {
    for (auto& v : br.ff_usage) {
      if ((v.second & e_D) && !(v.second & e_Q)) { // D but not Q
        auto B = ff_before.ff_usage.find(v.first);
        if (B != ff_before.ff_usage.end()) {
          if (B->second & e_Latch) {
            ff_after.ff_usage[v.first] = (e_FFUsage)((int)ff_after.ff_usage[v.first] | e_Q);
          }
        }
      }
    }
  }
  // 2) which vars have to be latched if used after?
  // => all vars that are D in a branch but not in another
  for (const auto& br : ff_branches) {
    for (auto& v : br.ff_usage) {
      if (((v.second & e_D) || (v.second & (e_D|e_NoLatch))) && !(v.second & e_Q)) { // D but not Q, and not tagged as nolatch
        // verify it does not have e_NoLatch before
        bool has_nolatch_before = false;
        auto B = ff_before.ff_usage.find(v.first);
        if (B != ff_before.ff_usage.end()) {
          if (B->second & e_NoLatch) {
            has_nolatch_before = true;
          }
        }
        if ( ! has_nolatch_before ) {
          // not used in all branches? => latch if used next
          if (d_in_all.count(v.first) == 0) {
            ff_after.ff_usage[v.first] = (e_FFUsage)((int)ff_after.ff_usage[v.first] | e_Latch);
          }
        }
      }
    }
  }
  _ff_after = ff_after;
}

// -------------------------------------------------

void Algorithm::verifyMemberGroup(std::string member, siliceParser::GroupContext* group) const
{
  // -> check for existence
  for (auto v : group->varList()->var()) {
    if (v->declarationVar()->IDENTIFIER()->getText() == member) {
      return; // ok!
    }
  }
  reportError(sourceloc(group->IDENTIFIER()),"group '%s' does not contain a member '%s'",
    group->IDENTIFIER()->getText().c_str(), member.c_str());
}

// -------------------------------------------------

void Algorithm::verifyMemberInterface(std::string member, siliceParser::IntrfaceContext *intrface) const
{
  // -> check for existence
  for (auto io : intrface->ioList()->io()) {
    if (io->IDENTIFIER()->getText() == member) {
      return; // ok!
    }
  }
  reportError(sourceloc(intrface->IDENTIFIER()), "interface '%s' does not contain a member '%s'",
    intrface->IDENTIFIER()->getText().c_str(), member.c_str());
}

// -------------------------------------------------

void Algorithm::verifyMemberGroup(std::string member, const t_group_definition &gd) const
{
  if (gd.group != nullptr) {
    verifyMemberGroup(member, gd.group);
  } else if (gd.intrface != nullptr) {
    verifyMemberInterface(member, gd.intrface);
  } else {
    std::vector<std::string> mbrs = getGroupMembers(gd);
    if (std::find(mbrs.begin(), mbrs.end(), member) == mbrs.end()) {
      std::string grname = "group";
      if      (gd.blueprint != nullptr) grname = "instance";
      else if (gd.inout != nullptr)     grname = "inout";
      else if (gd.intrface != nullptr)  grname = "interface";
      else if (gd.memory != nullptr)    grname = "memory";
      reportError(t_source_loc(), "%s does not contain a member '%s'", grname.c_str(), member.c_str());
    }
  }
}

// -------------------------------------------------

std::vector<std::string> Algorithm::getGroupMembers(const t_group_definition &gd) const
{
  std::vector<std::string> mbs;
  if (gd.group != nullptr) {
    for (auto v : gd.group->varList()->var()) {
      mbs.push_back(v->declarationVar()->IDENTIFIER()->getText());
    }
  } else if (gd.intrface != nullptr) {
    for (auto io : gd.intrface->ioList()->io()) {
      mbs.push_back(io->IDENTIFIER()->getText());
    }
  } else if (gd.memory != nullptr) {
    const t_mem_nfo &nfo = m_Memories.at(m_MemoryNames.at(gd.memory->name->getText()));
    return nfo.members;
  } else if (gd.blueprint != nullptr) {
    std::vector<std::string> names;
    for (const auto &o : gd.blueprint->outputNames()) {
      names.push_back(o.first);
    }
    return names;
  } else if (gd.inout != nullptr) {
    return c_InOutmembers;
  }
  return mbs;
}

// -------------------------------------------------

void Algorithm::verifyMemberBitfield(std::string member, siliceParser::BitfieldContext* field) const
{
  // -> check for existence
  for (auto v : field->varList()->var()) {
    if (v->declarationVar()->IDENTIFIER()->getText() == member) {
      // verify there is no initializer
      if (v->declarationVar()->declarationVarInitSet() != nullptr || v->declarationVar()->declarationVarInitCstr() != nullptr) {
        reportError(sourceloc(v),
          "bitfield members should not be given initial values (field '%s', member '%s')",
          field->IDENTIFIER()->getText().c_str(), member.c_str());
      }
      // verify type is uint
      if (v->declarationVar()->type()->TYPE() == nullptr) {
        reportError(sourceloc(v), "a bitfield cannot contain a 'sameas' definition");
      }
      sl_assert(v->declarationVar()->type()->TYPE() != nullptr);
      string test = v->declarationVar()->type()->TYPE()->getText();
      if (v->declarationVar()->type()->TYPE()->getText()[0] != 'u') {
        reportError(sourceloc(v),
          "bitfield members can only be unsigned (field '%s', member '%s')",
          field->IDENTIFIER()->getText().c_str(), member.c_str());
      }
      return; // ok!
    }
  }
  reportError(t_source_loc(), "bitfield '%s' does not contain a member '%s'",
    field->IDENTIFIER()->getText().c_str(), member.c_str());
}

// -------------------------------------------------

std::string Algorithm::bindingRightIdentifier(const t_binding_nfo& bnd, const t_combinational_block_context* bctx) const
{
  if (std::holds_alternative<std::string>(bnd.right)) {
    return translateVIOName(std::get<std::string>(bnd.right), bctx);
  } else {
    return determineAccessedVar(std::get<siliceParser::AccessContext*>(bnd.right), bctx);
  }
}

// -------------------------------------------------

std::string Algorithm::determineAccessedVar(siliceParser::IoAccessContext* access,const t_combinational_block_context* bctx) const
{
  std::string base = access->base->getText();
  base = translateVIOName(base, bctx);
  if (access->IDENTIFIER().size() != 2) {
    reportError(sourceloc(access),"'.' access depth limited to one in current version '%s'", base.c_str());
  }
  std::string member = access->IDENTIFIER()[1]->getText();
  // find blueprint
  auto B = m_InstancedBlueprints.find(base);
  if (B != m_InstancedBlueprints.end()) {
    return B->second.instance_prefix + "_" + member;
  } else {
    auto G = m_VIOGroups.find(base);
    if (G != m_VIOGroups.end()) {
      verifyMemberGroup(member, G->second);
      // return the group member name
      return base + "_" + member;
    } else {
      reportError(sourceloc(access),
        "cannot find accessed base.member '%s.%s'", base.c_str(), member.c_str());
    }
  }
  return "";
}

// -------------------------------------------------

std::string Algorithm::determineAccessedVar(siliceParser::BitfieldAccessContext* bfaccess, const t_combinational_block_context* bctx) const
{
  if (bfaccess->tableAccess() != nullptr) {
    return determineAccessedVar(bfaccess->tableAccess(), bctx);
  } else if (bfaccess->idOrIoAccess()->ioAccess() != nullptr) {
    return determineAccessedVar(bfaccess->idOrIoAccess()->ioAccess(), bctx);
  } else {
    return translateVIOName(bfaccess->idOrIoAccess()->IDENTIFIER()->getText(),bctx);
  }
}

// -------------------------------------------------

std::string Algorithm::determineAccessedVar(siliceParser::PartSelectContext* access,const t_combinational_block_context* bctx) const
{
  if (access->ioAccess() != nullptr) {
    return determineAccessedVar(access->ioAccess(), bctx);
  } else if (access->tableAccess() != nullptr) {
    return determineAccessedVar(access->tableAccess(), bctx);
  } else {
    return translateVIOName(access->IDENTIFIER()->getText(), bctx);
  }
}

// -------------------------------------------------

std::string Algorithm::determineAccessedVar(siliceParser::TableAccessContext* access,const t_combinational_block_context* bctx) const
{
  if (access->ioAccess() != nullptr) {
    return determineAccessedVar(access->ioAccess(), bctx);
  } else {
    return translateVIOName(access->IDENTIFIER()->getText(),bctx);
  }
}

// -------------------------------------------------

std::string Algorithm::determineAccessedVar(siliceParser::AccessContext* access, const t_combinational_block_context* bctx) const
{
  sl_assert(access != nullptr);
  if (access->ioAccess() != nullptr) {
    return determineAccessedVar(access->ioAccess(), bctx);
  } else if (access->tableAccess() != nullptr) {
    return determineAccessedVar(access->tableAccess(), bctx);
  } else if (access->partSelect() != nullptr) {
    return determineAccessedVar(access->partSelect(), bctx);
  } else if (access->bitfieldAccess() != nullptr) {
    return determineAccessedVar(access->bitfieldAccess(), bctx);
  }
  reportError(sourceloc(access), "internal error [%s, %d]",  __FILE__, __LINE__);
  return "";
}

// -------------------------------------------------

void Algorithm::determineVIOAccess(
  antlr4::tree::ParseTree*                    node,
  const std::unordered_map<std::string, int>& vios,
  const t_combinational_block_context        *bctx,
  std::unordered_set<std::string>& _read, std::unordered_set<std::string>& _written) const
{
  if (node->children.empty()) {
    // read accesses are children
    auto term = dynamic_cast<antlr4::tree::TerminalNode*>(node);
    if (term) {
      if (term->getSymbol()->getType() == siliceParser::IDENTIFIER) {
        std::string var = term->getText();
        var = translateVIOName(var, bctx);
        // is it a var?
        if (vios.find(var) != vios.end()) {
          _read.insert(var);
        } else {
          // is it a group? (in a call)
          auto G = m_VIOGroups.find(var);
          if (G != m_VIOGroups.end()) {
            // add all members
            for (auto mbr : getGroupMembers(G->second)) {
              std::string name = var + "_" + mbr;
              _read.insert(name);
            }
          }
        }
      }
    }
  } else {
    // track writes explicitely
    bool recurse = true;
    {
      auto assign = dynamic_cast<siliceParser::AssignmentContext*>(node);
      if (assign) {
        // retrieve var
        std::string var;
        if (assign->access() != nullptr) {
          var = determineAccessedVar(assign->access(), bctx);
        } else {
          var = assign->IDENTIFIER()->getText();
        }
        // tag var as written
        if (!var.empty()) {
          var = translateVIOName(var, bctx);
          if (!var.empty() && vios.find(var) != vios.end()) {
            _written.insert(var);
          }
        }
        // recurse on rhs expression
        determineVIOAccess(assign->expression_0(), vios, bctx, _read, _written);
        // recurse on lhs expression, if any
        if (assign->access() != nullptr) {
          if (assign->access()->tableAccess() != nullptr) {
            determineVIOAccess(assign->access()->tableAccess()->expression_0(), vios, bctx, _read, _written);
          } else if (assign->access()->partSelect() != nullptr) {
            determineVIOAccess(assign->access()->partSelect()->expression_0(), vios, bctx, _read, _written);
            /// NOTE: possible tag as a partial write, since this is a part select
          }
        }
        recurse = false;
      }
    } {
      auto alw = dynamic_cast<siliceParser::AlwaysAssignedContext*>(node);
      if (alw) {
        // retrieve var
        std::string var;
        if (alw->access() != nullptr) {
          var = determineAccessedVar(alw->access(), bctx);
        } else {
          var = alw->IDENTIFIER()->getText();
        }
        if (!var.empty()) {
          var = translateVIOName(var, bctx);
          if (vios.find(var) != vios.end()) {
            _written.insert(var);
          }
        }
        if (alw->ALWSASSIGNDBL() != nullptr) { // delayed flip-flop
          // update temp var usage
          std::string tmpvar = "delayed_" + std::to_string(alw->getStart()->getLine()) + "_" + std::to_string(alw->getStart()->getCharPositionInLine());
          if (vios.find(tmpvar) != vios.end()) {
            _read.insert(tmpvar);
            _written.insert(tmpvar);
          }
        }
        // recurse on rhs expression
        determineVIOAccess(alw->expression_0(), vios, bctx, _read, _written);
        // recurse on lhs expression, if any
        if (alw->access() != nullptr) {
          if (alw->access()->tableAccess() != nullptr) {
            determineVIOAccess(alw->access()->tableAccess()->expression_0(), vios, bctx, _read, _written);
          } else if (alw->access()->partSelect() != nullptr) {
            determineVIOAccess(alw->access()->partSelect()->expression_0(), vios, bctx, _read, _written);
          }
        }
        recurse = false;
      }
    } {
      auto sync = dynamic_cast<siliceParser::SyncExecContext*>(node);
      if (sync) {
        // calling a subroutine?
        auto S = m_Subroutines.find(sync->joinExec()->IDENTIFIER()->getText());
        if (S != m_Subroutines.end()) {
          // inputs
          for (const auto& i : S->second->inputs) {
            string var = S->second->vios.at(i);
            if (vios.find(var) != vios.end()) {
              _written.insert(var);
            } else {
              // is it a group? (in a call)
              auto G = m_VIOGroups.find(var);
              if (G != m_VIOGroups.end()) {
                // add all members
                for (auto mbr : getGroupMembers(G->second)) {
                  std::string name = var + "_" + mbr;
                  _written.insert(name);
                }
              }
            }
          }
        }
        // calling a blueprint?
        auto B = m_InstancedBlueprints.find(sync->joinExec()->IDENTIFIER()->getText());
        if (B != m_InstancedBlueprints.end()) {
          // if params are empty we skip, otherwise we mark the input as written
          auto plist = sync->callParamList();
          if (!plist->expression_0().empty()) {
            // inputs
            for (const auto& i : B->second.blueprint->inputs()) {
              string var = B->second.instance_prefix + "_" + i.name;
              if (vios.find(var) != vios.end()) {
                _written.insert(var);
              } else {
                // is it a group? (in a call)
                auto G = m_VIOGroups.find(var);
                if (G != m_VIOGroups.end()) {
                  // add all members
                  for (auto mbr : getGroupMembers(G->second)) {
                    std::string name = var + "_" + mbr;
                    _written.insert(name);
                  }
                }
              }
            }
          }
        }
        // do not blindly recurse otherwise the child 'join' is reached
        recurse = false;
        // detect reads on parameters
        for (auto c : node->children) {
          if (dynamic_cast<siliceParser::JoinExecContext*>(c) != nullptr) {
            // skip join, taken into account in return block
            continue;
          }
          determineVIOAccess(c, vios, bctx, _read, _written);
        }
      }
    } {
      auto async = dynamic_cast<siliceParser::AsyncExecContext*>(node);
      if (async) {
        // retrieve called a blueprint (cannot be a subroutine as these do not support async calls)
        auto B = m_InstancedBlueprints.find(async->IDENTIFIER()->getText());
        if (B != m_InstancedBlueprints.end()) {
          // if params are empty we skip, otherwise we mark the input as written
          auto plist = async->callParamList();
          if (!plist->expression_0().empty()) {
            // inputs
            for (const auto& i : B->second.blueprint->inputs()) {
              string var = B->second.instance_prefix + "_" + i.name;
              if (vios.find(var) != vios.end()) {
                _written.insert(var);
              } else {
                // is it a group? (in a call)
                auto G = m_VIOGroups.find(var);
                if (G != m_VIOGroups.end()) {
                  // add all members
                  for (auto mbr : getGroupMembers(G->second)) {
                    std::string name = var + "_" + mbr;
                    _written.insert(name);
                  }
                }
              }
            }
          }
        }
        // detect reads on parameters
        for (auto c : node->children) {
          determineVIOAccess(c, vios, bctx, _read, _written);
        }
      }
    } {
      auto join = dynamic_cast<siliceParser::JoinExecContext*>(node);
      if (join) {
        // track writes when reading back
        for (const auto& asgn : join->callParamList()->expression_0()) {
          std::string var;
          // which var is accessed?
          siliceParser::AccessContext *access = nullptr;
          std::string identifier;
          if (isAccess(asgn, access)) {
            var = determineAccessedVar(access, bctx);
          } else if (isIdentifier(asgn, identifier)) {
            var = identifier;
          } else {
            reportError(sourceloc(asgn), "cannot assign a return value to this expression");
          }
          if (!var.empty()) {
            var = translateVIOName(var, bctx);
            if (!var.empty() && vios.find(var) != vios.end()) {
              _written.insert(var);
            } else {
              // is it a group? (in a call)
              auto G = m_VIOGroups.find(var);
              if (G != m_VIOGroups.end()) {
                // add all members
                for (auto mbr : getGroupMembers(G->second)) {
                  std::string name = var + "_" + mbr;
                  _written.insert(name);
                }
              }
            }
          }
          // recurse on lhs expression, if any
          if (access != nullptr) {
            if (access->tableAccess() != nullptr) {
              determineVIOAccess(access->tableAccess()->expression_0(), vios, bctx, _read, _written);
            } else if (access->partSelect() != nullptr) {
              determineVIOAccess(access->partSelect()->expression_0(), vios, bctx, _read, _written);
            }
          }
        }
        // readback results from a subroutine?
        auto S = m_Subroutines.find(join->IDENTIFIER()->getText());
        if (S != m_Subroutines.end()) {
          // track reads of subroutine outputs
          for (const auto& o : S->second->outputs) {
            _read.insert(S->second->vios.at(o));
          }
        }
        recurse = false;
      }
    } {
      auto ioa = dynamic_cast<siliceParser::IoAccessContext*>(node);
      if (ioa) {
        // special case for io access read
        std::string var = determineAccessedVar(ioa,bctx);
        if (!var.empty()) {
          if (vios.find(var) != vios.end()) {
            _read.insert(var);
          }
        }
        recurse = false;
      }
    } {
      auto bfa = dynamic_cast<siliceParser::BitfieldAccessContext *>(node);
      if (bfa) {
        // special case for bitfield access read
        std::string var = determineAccessedVar(bfa, bctx);
        if (!var.empty()) {
          if (vios.find(var) != vios.end()) {
            _read.insert(var);
          }
        }
        recurse = false;
      }
    } {
      auto atom = dynamic_cast<siliceParser::AtomContext *>(node);
      if (atom) {
        if (atom->WIDTHOF() != nullptr) {
          // ignore widthof parameter, it is not read but 'examined' for its width
          recurse = false;
        }
      }
    } {
      auto cstv = dynamic_cast<siliceParser::ConstValueContext *>(node);
      if (cstv) {
        if (cstv->WIDTHOF() != nullptr) {
          // ignore widthof parameter, it is not read but 'examined' for its width
          recurse = false;
        }
      }
    }
    // recurse
    if (recurse) {
      for (auto c : node->children) {
        determineVIOAccess(c, vios, bctx, _read, _written);
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::determineOutOfPipelineAssignments(
  antlr4::tree::ParseTree *node,
  const std::unordered_map<std::string, int> &vios,
  const t_combinational_block_context *bctx,
  std::unordered_set<std::string> &_ex_written_before, std::unordered_set<std::string> &_ex_written_after,
  std::unordered_set<std::string> &_not_ex_written) const
{
  auto assign = dynamic_cast<siliceParser::AssignmentContext *>(node);
  if (assign) {
      // retrieve var
      std::string var;
      if (assign->access() != nullptr) {
        var = determineAccessedVar(assign->access(), bctx);
      } else {
        var = assign->IDENTIFIER()->getText();
      }
      // tag var as written
      if (!var.empty()) {
        var = translateVIOName(var, bctx);
        if (!var.empty() && vios.find(var) != vios.end()) {
          if (assign->OUTASSIGN_AFTER() != nullptr) {
            _ex_written_after.insert(var);
          } else if (assign->OUTASSIGN_BEFORE() != nullptr) {
            _ex_written_before.insert(var);
          } else {
            _not_ex_written.insert(var);
          }
        }
      }
  } else {
    // recurse
    for (auto c : node->children) {
      determineOutOfPipelineAssignments(c, vios, bctx, _ex_written_before,_ex_written_after, _not_ex_written);
    }
  }
}

// -------------------------------------------------

void Algorithm::determineAccess(
  antlr4::tree::ParseTree             *instr,
  const t_combinational_block_context *context,
  std::unordered_set<std::string>&   _already_written,
  std::unordered_set<std::string>&   _in_vars_read,
  std::unordered_set<std::string>&   _out_vars_written
  )
{
  std::unordered_set<std::string> read;
  std::unordered_set<std::string> written;
  determineVIOAccess(instr, m_VarNames, context, read, written);
  determineVIOAccess(instr, m_OutputNames, context, read, written);
  // record which are read from outside
  for (auto r : read) {
    // if read and not written before in block
    if (_already_written.find(r) == _already_written.end()) {
      _in_vars_read.insert(r); // value from prior block is read
    }
  }
  // record which are written to
  _already_written .insert(written.begin(), written.end());
  _out_vars_written.insert(written.begin(), written.end());
  // update global use
  for (auto r : read) {
    if (m_VarNames.find(r) != m_VarNames.end()) {
      m_Vars[m_VarNames.at(r)].access = (e_Access)(m_Vars[m_VarNames.at(r)].access | e_ReadOnly);
    }
    if (m_OutputNames.find(r) != m_OutputNames.end()) {
      m_Outputs[m_OutputNames.at(r)].access = (e_Access)(m_Outputs[m_OutputNames.at(r)].access | e_ReadOnly);
    }
  }
  for (auto w : written) {
    if (m_VarNames.find(w) != m_VarNames.end()) {
      m_Vars[m_VarNames.at(w)].access = (e_Access)(m_Vars[m_VarNames.at(w)].access | e_WriteOnly);
    }
    if (m_OutputNames.find(w) != m_OutputNames.end()) {
      m_Outputs[m_OutputNames.at(w)].access = (e_Access)(m_Outputs[m_OutputNames.at(w)].access | e_WriteOnly);
    }
  }
}

// -------------------------------------------------

void Algorithm::determineAccess(t_combinational_block *block)
{
  // determine variable access
  std::unordered_set<std::string> already_written;
  std::vector<t_instr_nfo> instr = block->instructions;
  if (block->if_then_else()) {
    instr.push_back(block->if_then_else()->test);
  }
  if (block->switch_case()) {
    instr.push_back(block->switch_case()->test);
  }
  if (block->while_loop()) {
    instr.push_back(block->while_loop()->test);
  }
  for (const auto& i : instr) {
    determineAccess(i.instr, &block->context, already_written, block->in_vars_read, block->out_vars_written);
  }
}

// -------------------------------------------------

template<typename T_nfo>
void Algorithm::updateAccessFromBinding(const t_binding_nfo &b,
  const std::unordered_map<std::string, int >& names, std::vector< T_nfo >& _nfos)
{
  if (names.find(bindingRightIdentifier(b)) != names.end()) {
    if (b.dir == e_Left || b.dir == e_LeftQ) {
      // add to always block dependency ; bound input are read /after/ combinational block
      m_AlwaysPost.in_vars_read.insert(bindingRightIdentifier(b));
      // set global access
      _nfos[names.at(bindingRightIdentifier(b))].access = (e_Access)(_nfos[names.at(bindingRightIdentifier(b))].access | e_ReadOnly);
    } else if (b.dir == e_Right) {
      // add to always block dependency ; bound output are written /before/ combinational block
      m_AlwaysPre.out_vars_written.insert(bindingRightIdentifier(b));
      // set global access
      // -> check prior access
      if (_nfos[names.at(bindingRightIdentifier(b))].access & e_WriteOnly) {
        reportError(b.srcloc, "cannot write to variable '%s' bound to an algorithm or module output", bindingRightIdentifier(b).c_str());
      }
      // -> mark as write-binded
      _nfos[names.at(bindingRightIdentifier(b))].access = (e_Access)(_nfos[names.at(bindingRightIdentifier(b))].access | e_WriteBinded);
    } else { // e_BiDir
      sl_assert(b.dir == e_BiDir);
      // -> check prior access
      if ((_nfos[names.at(bindingRightIdentifier(b))].access & (~e_ReadWriteBinded)) != 0) {
        reportError(b.srcloc, "cannot bind variable '%s' on an inout port, it is used elsewhere", bindingRightIdentifier(b).c_str());
      }
      // add to always block dependency
      m_AlwaysPost.in_vars_read.insert(bindingRightIdentifier(b)); // read after
      m_AlwaysPre.out_vars_written.insert(bindingRightIdentifier(b)); // written before
      // set global access
      _nfos[names.at(bindingRightIdentifier(b))].access = (e_Access)(_nfos[names.at(bindingRightIdentifier(b))].access | e_ReadWriteBinded);
    }
  }
}

// -------------------------------------------------

void Algorithm::determineAccessForWires(
  std::unordered_set<std::string> &_global_in_read,
  std::unordered_set<std::string> &_global_out_written
) {
  // first we gather all wires (bound expressions)
  std::unordered_map<std::string, t_instr_nfo> all_wires;
  std::queue<std::string> q_wires;
  for (const auto &v : m_Vars) {
    if (v.usage == e_Wire && m_WireAssignmentNames.count(v.name) > 0) { // this is a wire (bound expression)
      // find corresponding wire assignement
      int wai        = m_WireAssignmentNames.at(v.name);
      const auto &wa = m_WireAssignments[wai].second;
      auto alw = dynamic_cast<siliceParser::AlwaysAssignedContext *>(wa.instr);
      sl_assert(alw != nullptr);
      sl_assert(alw->IDENTIFIER() != nullptr);
      string var = translateVIOName(alw->IDENTIFIER()->getText(), &wa.block->context);
      if (var == v.name) { // found it
        all_wires.insert(make_pair(v.name, wa));
        if (v.access != e_NotAccessed) { // used in design
          sl_assert(v.access == e_ReadOnly); // there should not be any other use for a bound expression
          // add to stack
          q_wires.push(v.name);
        }
      }
    }
  }
  // gather wires
  // -> these are bound expressions, accessed only if the corresp. variable is used
  unordered_set<std::string> processed;
  while (!q_wires.empty()) { // requires mutiple passes
    auto w = q_wires.front();
    q_wires.pop();
    if (processed.count(w) == 0) { // skip if processed already
      processed.insert(w);
      // add access based on wire expression
      std::unordered_set<std::string> _,in_read;
      determineAccess(all_wires.at(w).instr, &all_wires.at(w).block->context, _, in_read, _global_out_written);
      // foreach read vio
      for (auto v : in_read) {
        // insert in global set
        _global_in_read.insert(v);
        // check if this used a new wire?
        if (all_wires.count(v) > 0 && processed.count(v) == 0) {
          // promote as accessed
          m_Vars.at(m_VarNames.at(v)).access = (e_Access)(m_Vars.at(m_VarNames.at(v)).access | e_ReadOnly);
          // recurse
          q_wires.push(v);
        }
      }
    }
  }

}

// -------------------------------------------------

void Algorithm::determineAccess(
  std::unordered_set<std::string>& _global_in_read,
  std::unordered_set<std::string>& _global_out_written
)
{
  // for all blocks
  for (auto& b : m_Blocks) {
    if (b->state_id == -1 && b->is_state) {
      continue; // block is never reached
    }
    determineAccess(b);
  }
  // determine variable access for always blocks
  determineAccess(&m_AlwaysPre);
  determineAccess(&m_AlwaysPost);
  // determine variable access due to instances
  // -> bindings are considered as belonging to the always pre block
  std::vector<t_binding_nfo> all_bindings;
  for (const auto& bp : m_InstancedBlueprints) {
    all_bindings.insert(all_bindings.end(), bp.second.bindings.begin(), bp.second.bindings.end());
  }
  for (const auto& b : all_bindings) {
    // variables
    updateAccessFromBinding(b, m_VarNames, m_Vars);
    // outputs
    updateAccessFromBinding(b, m_OutputNames, m_Outputs);
  }
  // -> non bound inputs are read
  for (const auto& bp : m_InstancedBlueprints) {
    for (const auto &is : bp.second.blueprint->inputs()) {
      if (bp.second.boundinputs.count(is.name) == 0) {
        std::string v = bp.second.instance_prefix + "_" + is.name;
        // add to always block dependency
        m_AlwaysPost.in_vars_read.insert(v);
        // set global access
        m_Vars[m_VarNames[v]].access = (e_Access)(m_Vars[m_VarNames[v]].access | e_ReadOnly);
      }
    }
  }
  // determine variable access due to instances clocks and reset
  for (const auto& bp : m_InstancedBlueprints) {
    std::vector<std::string> candidates;
    candidates.push_back(bp.second.instance_clock);
    candidates.push_back(bp.second.instance_reset);
    for (auto v : candidates) {
      // variables only
      if (m_VarNames.find(v) != m_VarNames.end()) {
        // add to always block dependency
        m_AlwaysPost.in_vars_read.insert(v);
        // set global access
        m_Vars[m_VarNames[v]].access = (e_Access)(m_Vars[m_VarNames[v]].access | e_ReadOnly);
      }
    }
  }
  // determine access to memory variables
  for (auto& mem : m_Memories) {
    for (auto& inv : mem.in_vars) { // input to memory
      // add to always block dependency
      m_AlwaysPost.in_vars_read.insert(inv.second);
      // set global access
      m_Vars[m_VarNames.at(inv.second)].access = (e_Access)(m_Vars[m_VarNames.at(inv.second)].access | e_ReadOnly);
    }
    for (auto& ouv : mem.out_vars) { // output from memory
      // add to always block dependency
      m_AlwaysPre.out_vars_written.insert(ouv.second);
      // -> check prior access
      if (m_Vars[m_VarNames.at(ouv.second)].access & e_WriteOnly) {
        reportError(mem.srcloc, "cannot write to variable '%s' bound to a memory output", ouv.second.c_str());
      }
      // set global access
      m_Vars[m_VarNames.at(ouv.second)].access = (e_Access)(m_Vars[m_VarNames.at(ouv.second)].access | e_WriteBinded);
    }
  }
  // determine access to inout variables
  for (const auto& io : m_InOuts) {
    if (m_VIOToBlueprintInOutsBound.count(io.name) == 0) {
      // inout io is possibly used in this algorithm as it is not bound to any blueprint
      bool is_input = true; // expects first in c_InOutmembers to be the input
      for (auto m : c_InOutmembers) {
        string vname = io.name + "_" + m;
        if (is_input) {
          // nothing to do, special wire
          is_input = false;
        } else {
          auto& v = m_Vars[m_VarNames.at(vname)];
          if (v.access != e_NotAccessed) {
            // if it is accessed, a tri-state is produced and it is globally read
            _global_in_read.insert(vname);
            v.access = (e_Access)(v.access | e_ReadOnly);
          }
        }
      }
    }
  }
  // determine variable access for wires
  determineAccessForWires(_global_in_read, _global_out_written);
  // merge all in_reads and out_written
  auto all_blocks = m_Blocks;
  all_blocks.push_front(&m_AlwaysPre);
  all_blocks.push_front(&m_AlwaysPost);
  for (const auto &b : all_blocks) {
    _global_in_read    .insert(b->in_vars_read.begin(), b->in_vars_read.end());
    _global_out_written.insert(b->out_vars_written.begin(), b->out_vars_written.end());
  }
}

// -------------------------------------------------

void Algorithm::determineUsage()
{

  // NOTE The notion of block here ignores combinational chains. For this reason this is only a
  //      coarse pass, and a second, finer analysis is performed through the two-passes write (see writeAsModule).
  //      This pass is still useful to detect (in particular) consts.

  // determine variables access
  std::unordered_set<std::string> global_in_read;
  std::unordered_set<std::string> global_out_written;
  determineAccess(global_in_read, global_out_written);
  // set and report
  const bool report = false;
  if (report) std::cerr << "---< " << m_Name << "::variables >---" << nxl;
  for (auto& v : m_Vars) {
    if (v.usage != e_Undetermined) {
      switch (v.usage) {
      case e_Wire:  if (report) std::cerr << v.name << " => wire (by def)" << nxl; break;
      case e_Bound: if (report) std::cerr << v.name << " => write-binded (by def)" << nxl; break;
      default: throw Fatal("internal error (usage)");
      }
      continue; // usage is fixed by definition
    }
    if (v.access == e_ReadOnly) {
      if (report) std::cerr << v.name << " => const ";
      v.usage = e_Const;
    } else if (v.access == e_WriteOnly) {
      if (report) std::cerr << v.name << " => written but not used ";
      if (v.table_size == 0) {  // tables are not allowed to become temporary registers
        v.usage = e_Temporary; // e_NotUsed;
      } else {
        v.usage = e_FlipFlop;  // e_NotUsed;
      }
    } else if ((v.access == (e_WriteBinded | e_ReadOnly)) || (v.access == (e_WriteBinded | e_ReadOnly | e_InternalFlipFlop))) {
      if (report) std::cerr << v.name << " => write-binded ";
      v.usage = e_Bound;
    } else if (v.access == (e_WriteBinded) || (v.access == (e_WriteBinded | e_InternalFlipFlop))) {
      if (report) std::cerr << v.name << " => write-binded but not used ";
      v.usage = e_Bound;
    } else if (v.access & e_InternalFlipFlop) {
      if (report) std::cerr << v.name << " => internal flip-flop ";
      v.usage = e_FlipFlop;
    } else if (v.access == e_ReadWrite) {
      if ( v.table_size == 0  // tables are not allowed to become temporary registers
        && global_in_read.find(v.name) == global_in_read.end()) {
        if (report) std::cerr << v.name << " => temp ";
        v.usage = e_Temporary;
      } else {
        if (report) std::cerr << v.name << " => flip-flop ";
        v.usage = e_FlipFlop;
      }
    } else if (v.access == e_NotAccessed) {
      if (report) std::cerr << v.name << " => unused ";
      v.usage = e_NotUsed;
    } else if (v.access == e_ReadWriteBinded) {
      if (report) std::cerr << v.name << " => bound to inout ";
      v.usage = e_Bound;
    } else  {
      throw Fatal("interal error -- variable '%s' has an unknown usage pattern", v.name.c_str());
    }
    if (report) std::cerr << nxl;
  }
  if (report) std::cerr << "---< " << m_Name << "::outputs >---" << nxl;
  for (auto &o : m_Outputs) {
    if (o.access == (e_WriteBinded | e_ReadOnly)) {
      if (report) std::cerr << o.name << " => bound (wire)";
      o.usage = e_Bound;
    } else if (o.access == (e_WriteBinded)) {
      if (report) std::cerr << o.name << " => bound (wire)";
      o.usage = e_Bound;
    } else  {
      if (report) std::cerr << o.name << " => flip-flop";
      o.usage = e_FlipFlop;
    }
    if (report) std::cerr << nxl;
  }

}

// -------------------------------------------------

void Algorithm::determineBlueprintBoundVIO(const t_instantiation_context& ictx)
{
  // find out vio bound to a blueprint output
  for (const auto& ib : m_InstancedBlueprints) {
    for (const auto& b : ib.second.bindings) {
      if (b.dir == e_Right) {
        // record wire name for this output
        string wire = WIRE + ib.second.instance_prefix + "_" + b.left;
        // -> is there a part access?
        bool part_access = false;
        if (!std::holds_alternative<std::string>(b.right)) {
          /// NOTE we assume ranges can be resolved as integers, error otherwise
          auto access = std::get<siliceParser::AccessContext*>(b.right);
          auto range  = determineAccessConstBitRange(access, nullptr);
          if (range[0] > -1) {
            // yes, part access on bound var
            part_access = true;
            // attempt to find vios
            bool lfound = false;
            t_var_nfo ldef = ib.second.blueprint->getVIODefinition(b.left,lfound);
            if (!lfound) {
              reportError(sourceloc(access), "cannot find bound output '%s'", b.left.c_str());
            }
            bool rfound = false;
            t_var_nfo rdef = getVIODefinition(bindingRightIdentifier(b), rfound);
            if (!rfound) {
              reportError(sourceloc(access), "cannot find bound vio '%s'", bindingRightIdentifier(b).c_str());
            }
            // check width of output vs range width
            // -> get output width if possible
            {
              int iobw = -1;
              string obw = ib.second.blueprint->resolveWidthOf(b.left, ictx, sourceloc(access));
              try {
                iobw = stoi(obw);
              } catch (...) {
                iobw = -1;
                if (ldef.type_nfo.base_type != Parameterized) { // can happen if parameterized
                  reportError(sourceloc(access), "cannot determine width of bound output '%s' (width string is '%s')", b.left.c_str(), obw.c_str());
                }
              }
              // -> checks
              if (iobw > -1) {
                if (range[1] > iobw) {
                  reportError(sourceloc(access), "bound vio '%s' width is larger than output '%s' width", bindingRightIdentifier(b).c_str(), b.left.c_str());
                } else if (range[1] < iobw) {
                  reportError(sourceloc(access), "bound vio '%s' selected width is smaller than output '%s' width", bindingRightIdentifier(b).c_str(), b.left.c_str());
                }
              }
            }
            // -> get bound var width (should always succeed)
            {
              int ibbw = -1;
              string bbw = resolveWidthOf(bindingRightIdentifier(b), ictx, sourceloc(access));
              try {
                ibbw = stoi(bbw);
              } catch (...) {
                reportError(sourceloc(access), "cannot determine width of bound vio '%s' (width string is '%s')", bindingRightIdentifier(b).c_str(), bbw.c_str());
              }
              // -> checks
              if (range[0] + range[1] > ibbw) {
                reportError(sourceloc(access), "bit select is out of bounds on vio '%s'", bindingRightIdentifier(b).c_str());
              }
            }
            // add to the list
            m_VIOBoundToBlueprintOutputs[bindingRightIdentifier(b)] += ";" + wire + "," + std::to_string(range[0]) + "," + std::to_string(range[1]);
          }
        }
        if (!part_access) {
          // check not already bound
          if (m_VIOBoundToBlueprintOutputs.find(bindingRightIdentifier(b)) != m_VIOBoundToBlueprintOutputs.end()) {
            reportError(b.srcloc, "vio '%s' is already bound as the output of another instance", bindingRightIdentifier(b).c_str());
          }
          // store
          m_VIOBoundToBlueprintOutputs[bindingRightIdentifier(b)] = wire;
        }
      } else if (b.dir == e_BiDir) {
        // check not already bound
        if (m_VIOBoundToBlueprintOutputs.find(bindingRightIdentifier(b)) != m_VIOBoundToBlueprintOutputs.end()) {
          reportError(b.srcloc, "vio '%s' is already bound as the output of another instance", bindingRightIdentifier(b).c_str());
        }
        // record wire name for this inout
        std::string bindpoint = ib.second.instance_prefix + "_" + b.left;
        m_BlueprintInOutsBoundToVIO[bindpoint] = bindingRightIdentifier(b);
        m_VIOToBlueprintInOutsBound[bindingRightIdentifier(b)] = bindpoint;
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::analyzeSubroutineCalls()
{
  for (const auto &b : m_Blocks) {
    // contains a subroutine call?
    if (b->goto_and_return_to()) {
      int call_id = m_SubroutineCallerNextId++;
      sl_assert(m_SubroutineCallerIds.count(b->goto_and_return_to()) == 0);
      m_SubroutineCallerIds.insert(std::make_pair(b->goto_and_return_to(), call_id));
      if (b->goto_and_return_to()->go_to->context.subroutine != nullptr) {
        // record return state
        m_SubroutinesCallerReturnStates[b->goto_and_return_to()->go_to->context.subroutine->name]
          .push_back(std::make_pair(
            call_id,
            b->goto_and_return_to()->return_to
          ));
        // if in subroutine, indicate it performs sub-calls
        if (b->context.subroutine != nullptr) {
          m_Subroutines.at(b->context.subroutine->name)->contains_calls = true;
        }
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::analyzeInstancedBlueprintInputs()
{
  for (auto& ib : m_InstancedBlueprints) {
    for (const auto& b : ib.second.bindings) {
      if (b.dir == e_Left || b.dir == e_LeftQ) { // setting input
        // input is bound directly
        ib.second.boundinputs.insert(make_pair(b.left, make_pair(b.right,b.dir == e_LeftQ ? e_Q : e_D)));
      }
    }
  }
}

// -------------------------------------------------

Algorithm::Algorithm(
  const std::unordered_map<std::string, siliceParser::SubroutineContext*>& known_subroutines,
  const std::unordered_map<std::string, siliceParser::CircuitryContext*>&  known_circuitries,
  const std::unordered_map<std::string, siliceParser::GroupContext*>&      known_groups,
  const std::unordered_map<std::string, siliceParser::IntrfaceContext *>&  known_interfaces,
  const std::unordered_map<std::string, siliceParser::BitfieldContext*>&   known_bitfield
) : m_KnownSubroutines(known_subroutines), m_KnownCircuitries(known_circuitries),
    m_KnownGroups(known_groups), m_KnownInterfaces(known_interfaces), m_KnownBitFields(known_bitfield)
{ }

// -------------------------------------------------

void Algorithm::init(
  std::string name, bool hasHash,
  std::string clock, std::string reset,
  bool autorun, bool onehot, std::string formalDepth, std::string formalTimeout, const std::vector<std::string> &modes
)
{
  m_Name = name;
  m_hasHash = hasHash;
  m_Clock = clock;
  m_Reset = reset;
  m_FormalDepth = formalDepth;
  m_FormalTimeout = formalTimeout;
  m_FormalModes = modes;
  m_AutoRun = autorun;
  m_OneHot = onehot;
  // eliminate any duplicate mode
  std::unique(std::begin(m_FormalModes), std::end(m_FormalModes));
  // order modes so that they are always performed in the same order:
  //  bmc --> temporal induction --> cover
  std::sort(std::begin(m_FormalModes), std::end(m_FormalModes),
            [] (std::string const &m1, std::string const &m2)
            // a mode is less than another one if it either:
            // - is a bmc (runs first)
            // - is a temporal induction compared to a cover (temporal induction runs first)
            { return (m1 == "bmc") || (m1 == "tind" && m2 == "cover"); });
  // init with empty always blocks
  m_AlwaysPre.id = -1;
  m_AlwaysPre .block_name = "_always_pre";
  m_AlwaysPost.id = -1;
  m_AlwaysPost.block_name = "_always_post";
}

// -------------------------------------------------

void Algorithm::gatherBody(antlr4::tree::ParseTree *body)
{
  // gather elements from source code
  t_combinational_block *main = addBlock("_top", nullptr);
  main->is_state = true;

  // context
  t_gather_context context;
  context.__id = -1;
  context.break_to = nullptr;

  // gather content
  gather(body, main, &context);

  // resolve forward refs
  resolveForwardJumpRefs();

  // determine return states for subroutine calls
  analyzeSubroutineCalls();

}

// -------------------------------------------------

void Algorithm::createInstancedBlueprintInputOutputVars(t_instanced_nfo& _bp)
{
  // create vars for non bound inputs, these are used with the 'dot' access syntax and allow access pattern analysis
  for (const auto& i : _bp.blueprint->inputs()) {
    if (_bp.boundinputs.count(i.name) == 0) {
      t_var_nfo vnfo = i;
      vnfo.name = _bp.instance_prefix + "_" + i.name;
      addVar(vnfo, m_Blocks.front(), t_source_loc());
    }
  }
  // create vars for outputs, these are used with the 'dot' access syntax and allow access pattern analysis
  for (const auto& o : _bp.blueprint->outputs()) {
    t_var_nfo vnfo = o;
    vnfo.name = _bp.instance_prefix + "_" + o.name;
    addVar(vnfo, m_Blocks.front(), t_source_loc());
    m_Vars.at(m_VarNames.at(vnfo.name)).access = e_WriteBinded;
    m_Vars.at(m_VarNames.at(vnfo.name)).usage = e_Bound;
    m_VIOBoundToBlueprintOutputs[vnfo.name] = WIRE + _bp.instance_prefix + "_" + o.name;
  }
}

// -------------------------------------------------

template<typename T_nfo>
void Algorithm::resolveTypeFromBlueprint(const t_instanced_nfo& bp, const t_instantiation_context &ictx, t_var_nfo& vnfo, T_nfo& ref)
{
  vnfo.type_nfo.base_type = bp.blueprint->varType(ref, ictx);
  vnfo.type_nfo.width     = atoi(bp.blueprint->varBitWidth(ref, ictx).c_str());
  vnfo.type_nfo.same_as   = "";
  sl_assert(vnfo.table_size == 0);
  std::string init = bp.blueprint->varInitValue(ref, ictx);
  if (!init.empty()) {
    vnfo.init_values.clear();
    vnfo.init_values.push_back(init);
  }
}

void Algorithm::resolveInstancedBlueprintInputOutputVarTypes(const t_instanced_nfo& bp, const t_instantiation_context &ictx)
{
  for (const auto& i : bp.blueprint->inputs()) {
    if (bp.boundinputs.count(i.name) == 0) {
      // not bound
      std::string name = bp.instance_prefix + "_" + i.name;
      auto& vnfo       = m_Vars.at(m_VarNames.at(name));
      if (vnfo.type_nfo.base_type == Parameterized) {
        // parameterized: has to be resolved
        resolveTypeFromBlueprint(bp, ictx, vnfo, i);
      }
    }
  }
  for (const auto& o : bp.blueprint->outputs()) {
    std::string name = bp.instance_prefix + "_" + o.name;
    auto& vnfo       = m_Vars.at(m_VarNames.at(name));
    if (vnfo.type_nfo.base_type == Parameterized) {
      // parameterized: has to be resolved
      resolveTypeFromBlueprint(bp, ictx, vnfo, o);
    }
  }
}

// -------------------------------------------------

void Algorithm::checkPermissions()
{
  // start by adding ins/outs of calls in subroutines
  for (auto& sub : m_Subroutines) {
    // -> check instance allowed calls ins/outs
    for (auto called : sub.second->allowed_calls) {
      auto S = m_Subroutines.find(called);
      if (S != m_Subroutines.end()) {
        for (auto ins : S->second->inputs) {
          sub.second->allowed_writes.insert(S->second->vios.at(ins));
        }
        for (auto outs : S->second->outputs) {
          sub.second->allowed_reads.insert(S->second->vios.at(outs));
        }
      } else {
        auto I = m_InstancedBlueprints.find(called);
        if (I != m_InstancedBlueprints.end()) {
          for (auto ins : I->second.blueprint->inputs()) {
            sub.second->allowed_writes.insert(I->second.instance_prefix + "_" + ins.name);
          }
          for (auto outs : I->second.blueprint->outputs()) {
            sub.second->allowed_reads.insert(I->second.instance_prefix + "_" + outs.name);
          }
        } else {
          reportError(t_source_loc(),
            "unknown unit or subroutine '%s' declared called by subroutine '%s'", called.c_str(), sub.second->name.c_str());
        }
      }
    }
  }
  // check permissions on all instructions of all blocks
  for (const auto &i : m_AlwaysPre.instructions) {
    checkPermissions(i.instr, &m_AlwaysPre);
  }
  for (const auto &i : m_AlwaysPost.instructions) {
    checkPermissions(i.instr, &m_AlwaysPost);
  }
  for (const auto &b : m_Blocks) {
    if (b->state_id == -1) {
      continue; // skip unreachable blocks
    }
    for (const auto &i : b->instructions) {
      checkPermissions(i.instr,b);
    }
    // check expressions in flow control
    if (b->if_then_else()) {
      checkPermissions(b->if_then_else()->test.instr, b);
    }
    if (b->switch_case()) {
      checkPermissions(b->switch_case()->test.instr, b);
    }
    if (b->while_loop()) {
      checkPermissions(b->while_loop()->test.instr, b);
    }
  }
}

// -------------------------------------------------

void Algorithm::checkExpressions(const t_instantiation_context &ictx,antlr4::tree::ParseTree *node, const t_combinational_block *_current)
{
  auto expr   = dynamic_cast<siliceParser::Expression_0Context*>(node);
  auto assign = dynamic_cast<siliceParser::AssignmentContext*>(node);
  auto alwasg = dynamic_cast<siliceParser::AlwaysAssignedContext*>(node);
  auto async  = dynamic_cast<siliceParser::AsyncExecContext *>(node);
  auto sync   = dynamic_cast<siliceParser::SyncExecContext *>(node);
  auto join   = dynamic_cast<siliceParser::JoinExecContext *>(node);
  if (expr) {
    ExpressionLinter linter(this,ictx);
    linter.lint(expr, &_current->context);
  } else if (assign) {
    ExpressionLinter linter(this,ictx);
    linter.lintAssignment(assign->access(),assign->IDENTIFIER(), assign->expression_0(), &_current->context);
  } else if (alwasg) {
    ExpressionLinter linter(this,ictx);
    linter.lintAssignment(alwasg->access(), alwasg->IDENTIFIER(), alwasg->expression_0(), &_current->context);
  } else if (async) {
    if (async->callParamList()) {
      // find algorithm
      auto A = m_InstancedBlueprints.find(async->IDENTIFIER()->getText());
      if (A != m_InstancedBlueprints.end()) {
        Algorithm *alg = dynamic_cast<Algorithm*>(A->second.blueprint.raw());
        if (alg == nullptr) {
          reportError(sourceloc(async), "called instance '%s' is not an algorithm", async->IDENTIFIER()->getText().c_str());
        } else {
          // if parameters are given, check, otherwise we allow call without parameters (bindings may exist)
          if (!async->callParamList()->expression_0().empty()) {
            // get params
            std::vector<t_call_param> matches;
            parseCallParams(async->callParamList(),alg, true, &_current->context, matches);
            // lint each
            int p = 0;
            for (const auto& ins : A->second.blueprint->inputs()) {
              ExpressionLinter linter(this, ictx);
              linter.lintInputParameter(ins.name, ins.type_nfo, matches[p++], &_current->context);
            }
          }
        }
      }
    }
  } else if (sync) {
    if (sync->callParamList()) {
      // find algorithm / subroutine
      auto A = m_InstancedBlueprints.find(sync->joinExec()->IDENTIFIER()->getText());
      if (A != m_InstancedBlueprints.end()) { // algorithm?
        Algorithm *alg = dynamic_cast<Algorithm*>(A->second.blueprint.raw());
        if (alg == nullptr) {
          reportError(sourceloc(async), "called instance '%s' is not an algorithm", async->IDENTIFIER()->getText().c_str());
        } else {
          // if parameters are given, check, otherwise we allow call without parameters (bindings may exist)
          if (!sync->callParamList()->expression_0().empty()) {
            // get params
            std::vector<t_call_param> matches;
            parseCallParams(sync->callParamList(), alg, true, &_current->context, matches);
            // lint each
            int p = 0;
            for (const auto& ins : A->second.blueprint->inputs()) {
              ExpressionLinter linter(this, ictx);
              linter.lintInputParameter(ins.name, ins.type_nfo, matches[p++], &_current->context);
            }
          }
        }
      } else {
        auto S = m_Subroutines.find(sync->joinExec()->IDENTIFIER()->getText());
        if (S != m_Subroutines.end()) { // subroutine
          // get params
          std::vector<t_call_param> matches;
          parseCallParams(sync->callParamList(), S->second, true, &_current->context, matches);
          // lint each
          int p = 0;
          for (const auto& ins : S->second->inputs) {
            const auto& info = m_Vars[m_VarNames.at(S->second->vios.at(ins))];
            ExpressionLinter linter(this,ictx);
            linter.lintInputParameter(ins, info.type_nfo, matches[p++], &_current->context);
          }
        }
      }
    }
  } else if (join) {
    if (!join->callParamList()->expression_0().empty()) {
      // find algorithm / subroutine
      auto A = m_InstancedBlueprints.find(join->IDENTIFIER()->getText());
      if (A != m_InstancedBlueprints.end()) { // algorithm?
        Algorithm *alg = dynamic_cast<Algorithm*>(A->second.blueprint.raw());
        if (alg == nullptr) {
          reportError(sourceloc(async), "joined instance '%s' is not an algorithm", async->IDENTIFIER()->getText().c_str());
        } else {
          // if parameters are given, check, otherwise we allow call without parameters (bindings may exist)
          if (!join->callParamList()->expression_0().empty()) {
            // get params
            std::vector<t_call_param> matches;
            parseCallParams(join->callParamList(), alg, false, &_current->context, matches);
            // lint each
            int p = 0;
            for (const auto& outs : A->second.blueprint->outputs()) {
              ExpressionLinter linter(this, ictx);
              linter.lintReadback(outs.name, matches[p++], outs.type_nfo, &_current->context);
            }
          }
        }
      } else {
        auto S = m_Subroutines.find(join->IDENTIFIER()->getText());
        if (S != m_Subroutines.end()) { // subroutine
          // get params
          std::vector<t_call_param> matches;
          parseCallParams(join->callParamList(), S->second, false, &_current->context, matches);
          // lint each
          int p = 0;
          for (const auto& outs : S->second->outputs) {
            ExpressionLinter linter(this,ictx);
            const auto& info = m_Vars[m_VarNames.at(S->second->vios.at(outs))];
            linter.lintReadback(outs, matches[p++], info.type_nfo, &_current->context);
          }
        }
      }
    }
  } else {
    for (auto c : node->children) {
      checkExpressions(ictx, c, _current);
    }
  }
}

// -------------------------------------------------

void Algorithm::checkExpressions(const t_instantiation_context &ictx)
{
  // check permissions on all instructions of all blocks
  for (const auto &i : m_AlwaysPre.instructions) {
    checkExpressions(ictx, i.instr, &m_AlwaysPre);
  }
  for (const auto &i : m_AlwaysPost.instructions) {
    checkExpressions(ictx, i.instr, &m_AlwaysPost);
  }
  // check wire assignments
  for (const auto &w : m_WireAssignments) {
    ExpressionLinter linter(this, ictx);
    linter.lintWireAssignment(w.second);
  }
  // check blocks
  for (const auto &b : m_Blocks) {
    if (b->state_id == -1) {
      continue; // skip unreachable blocks
    }
    for (const auto &i : b->instructions) {
      checkExpressions(ictx, i.instr, b);
    }
    // check expressions in flow control
    if (b->if_then_else()) {
      checkExpressions(ictx, b->if_then_else()->test.instr, b);
    }
    if (b->switch_case()) {
      checkExpressions(ictx, b->switch_case()->test.instr, b);
    }
    if (b->while_loop()) {
      checkExpressions(ictx, b->while_loop()->test.instr, b);
    }
  }
}

// -------------------------------------------------

void Algorithm::lint(const t_instantiation_context &ictx)
{
  // check bindings
  checkBlueprintsBindings(ictx);
  // check expressions
  checkExpressions(ictx);
}

// -------------------------------------------------

void Algorithm::resolveInOuts()
{
  for (const auto& io : m_InOuts) {
    if (m_VIOToBlueprintInOutsBound.count(io.name) == 0) {
      // inout io is possibly used in this algorithm as it is not bound to any blueprint
      // generate vars
      t_var_nfo v;
      var_nfo_copy(v, io);
      bool is_input = true; // expects first in c_InOutmembers to be the input
      for (auto m : c_InOutmembers) {
        v.name = io.name + "_" + m;
        if (is_input) {
          v.usage  = e_Wire;
          is_input = false;
        } else {
          v.usage  = io.usage;
        }
        addVar(v, m_Blocks.front(), t_source_loc());
      }
      // add group for member access and bindings
      m_VIOGroups.insert(make_pair(io.name, &io));
    }
  }
}

// -------------------------------------------------

void Algorithm::optimize(const t_instantiation_context& ictx)
{
  if (!m_Optimized) {
    // NOTE: recalls the algorithm is optimized, as it can be used by multiple instances
    // this paves the ways to having different optimizations for different instances
    m_Optimized = true;
    // generate states
    generateStates();
    // resolve inouts
    resolveInOuts();
    // determine which VIO are bound
    determineBlueprintBoundVIO(ictx);
    // analyze instances inputs
    analyzeInstancedBlueprintInputs();
    // check var access permissions
    checkPermissions();
    // analyze variables access
    determineUsage();
  }
}

// -------------------------------------------------

std::tuple<t_type_nfo, int> Algorithm::determineVIOTypeWidthAndTableSize(std::string vname, const t_source_loc& srcloc) const
{
  t_type_nfo tn;
  tn.base_type   = Int;
  tn.width       = -1;
  int table_size = 0;
  // test if variable
  if (m_VarNames.find(vname) != m_VarNames.end()) {
    tn         = m_Vars[m_VarNames.at(vname)].type_nfo;
    table_size = m_Vars[m_VarNames.at(vname)].table_size;
  } else if (vname == ALG_CLOCK) {
    tn         = t_type_nfo(UInt,1);
    table_size = 0;
  } else if (vname == ALG_RESET) {
    tn         = t_type_nfo(UInt,1);
    table_size = 0;
  } else {
    return Blueprint::determineVIOTypeWidthAndTableSize(vname, srcloc);
  }
  return std::make_tuple(tn, table_size);
}

// -------------------------------------------------

std::tuple<t_type_nfo, int> Algorithm::determineIdentifierTypeWidthAndTableSize(const t_combinational_block_context *bctx, antlr4::tree::TerminalNode *identifier, const t_source_loc& srcloc) const
{
  sl_assert(identifier != nullptr);
  std::string vname = identifier->getText();
  return determineVIOTypeWidthAndTableSize(translateVIOName(vname, bctx), srcloc);
}

// -------------------------------------------------

t_type_nfo Algorithm::determineIdentifierTypeAndWidth(const t_combinational_block_context *bctx, antlr4::tree::TerminalNode *identifier, const t_source_loc& srcloc) const
{
  sl_assert(identifier != nullptr);
  auto tws = determineIdentifierTypeWidthAndTableSize(bctx, identifier, srcloc);
  return std::get<0>(tws);
}

// -------------------------------------------------

t_type_nfo Algorithm::determineIOAccessTypeAndWidth(const t_combinational_block_context *bctx, siliceParser::IoAccessContext* ioaccess) const
{
  sl_assert(ioaccess != nullptr);
  std::string base = ioaccess->base->getText();
  // translate
  base = translateVIOName(base, bctx);
  if (ioaccess->IDENTIFIER().size() != 2) {
    reportError(sourceloc(ioaccess),
      "'.' access depth limited to one in current version '%s'", base.c_str());
  }
  std::string member = ioaccess->IDENTIFIER()[1]->getText();
  // accessing a blueprint?
  auto A = m_InstancedBlueprints.find(base);
  if (A != m_InstancedBlueprints.end()) {
    if (!A->second.blueprint->isInput(member) && !A->second.blueprint->isOutput(member)) {
      reportError(sourceloc(ioaccess),
        "'%s' is neither an input nor an output, instance '%s'", member.c_str(), base.c_str());
    }
    if (A->second.blueprint->isInput(member)) {
      if (A->second.boundinputs.count(member) > 0) {
        reportError(sourceloc(ioaccess),
          "cannot access bound input '%s' on instance '%s'", member.c_str(), base.c_str());
      }
      return A->second.blueprint->inputs()[A->second.blueprint->inputNames().at(member)].type_nfo;
    } else if (A->second.blueprint->isOutput(member)) {
      return A->second.blueprint->outputs()[A->second.blueprint->outputNames().at(member)].type_nfo;
    } else {
      sl_assert(false);
    }
  } else {
    auto G = m_VIOGroups.find(base);
    if (G != m_VIOGroups.end()) {
      verifyMemberGroup(member, G->second);
      // produce the variable name
      std::string vname = base + "_" + member;
      // get width and size
      auto tws = determineVIOTypeWidthAndTableSize(translateVIOName(vname, bctx), sourceloc(ioaccess));
      return std::get<0>(tws);
    } else {
      reportError(sourceloc(ioaccess),
        "cannot find accessed base.member '%s.%s'", base.c_str(), member.c_str());
    }
  }
  sl_assert(false);
  return t_type_nfo(UInt, 0);
}

// -------------------------------------------------

t_type_nfo Algorithm::determineBitfieldAccessTypeAndWidth(const t_combinational_block_context *bctx, siliceParser::BitfieldAccessContext *bfaccess) const
{
  sl_assert(bfaccess != nullptr);
  // check field definition exists
  auto F = m_KnownBitFields.find(bfaccess->field->getText());
  if (F == m_KnownBitFields.end()) {
    reportError(sourceloc(bfaccess), "unknown bitfield '%s'", bfaccess->field->getText().c_str());
  }
  // either identifier or ioaccess
  t_type_nfo packed;
  if (bfaccess->tableAccess() != nullptr) {
    packed = determineTableAccessTypeAndWidth(bctx, bfaccess->tableAccess());
  } else if (bfaccess->idOrIoAccess()->IDENTIFIER() != nullptr) {
    packed = determineIdentifierTypeAndWidth(bctx, bfaccess->idOrIoAccess()->IDENTIFIER(), sourceloc(bfaccess));
  } else {
    packed = determineIOAccessTypeAndWidth(bctx, bfaccess->idOrIoAccess()->ioAccess());
  }
  // get member
  verifyMemberBitfield(bfaccess->member->getText(), F->second);
  pair<t_type_nfo, int> ow = bitfieldMemberTypeAndOffset(F->second, bfaccess->member->getText());
  if (packed.base_type != Parameterized) { /// TODO: linter after generics are resolved
    if (ow.first.width + ow.second > packed.width) {
      reportError(sourceloc(bfaccess), "bitfield access '%s.%s' is out of bounds", bfaccess->field->getText().c_str(), bfaccess->member->getText().c_str());
    }
  }
  return ow.first;
}

// -------------------------------------------------

t_type_nfo Algorithm::determinePartSelectTypeAndWidth(const t_combinational_block_context *bctx, siliceParser::PartSelectContext *partsel) const
{
  sl_assert(partsel != nullptr);
  // accessed item
  t_type_nfo tn;
  if (partsel->IDENTIFIER() != nullptr) {
    tn = determineIdentifierTypeAndWidth(bctx, partsel->IDENTIFIER(), sourceloc(partsel));
  } else if (partsel->tableAccess() != nullptr) {
    tn = determineTableAccessTypeAndWidth(bctx, partsel->tableAccess());
  } else if (partsel->bitfieldAccess() != nullptr) {
    tn = determineBitfieldAccessTypeAndWidth(bctx, partsel->bitfieldAccess());
  } else {
    tn = determineIOAccessTypeAndWidth(bctx, partsel->ioAccess());
  }
  // const width
  int w = -1;
  try {
    w = std::stoi(gatherConstValue(partsel->num));
  } catch (...) {
    reportError(sourceloc(partsel), "the width has to be a simple number or the widthof() of a fully determined VIO");
  }
  if (w <= 0) {
    reportError(sourceloc(partsel), "width has to be greater than zero");
  }
  tn.width = w;
  return tn;
}

// -------------------------------------------------

t_type_nfo Algorithm::determineTableAccessTypeAndWidth(const t_combinational_block_context *bctx, siliceParser::TableAccessContext *tblaccess) const
{
  sl_assert(tblaccess != nullptr);
  if (tblaccess->IDENTIFIER() != nullptr) {
    return determineIdentifierTypeAndWidth(bctx, tblaccess->IDENTIFIER(), sourceloc(tblaccess));
  } else {
    return determineIOAccessTypeAndWidth(bctx, tblaccess->ioAccess());
  }
}

// -------------------------------------------------

t_type_nfo Algorithm::determineAccessTypeAndWidth(const t_combinational_block_context *bctx, siliceParser::AccessContext *access, antlr4::tree::TerminalNode *identifier) const
{
  if (access) {
    // table, output or bits
    if (access->ioAccess() != nullptr) {
      return determineIOAccessTypeAndWidth(bctx, access->ioAccess());
    } else if (access->tableAccess() != nullptr) {
      return determineTableAccessTypeAndWidth(bctx, access->tableAccess());
    } else if (access->partSelect() != nullptr) {
      return determinePartSelectTypeAndWidth(bctx, access->partSelect());
    } else if (access->bitfieldAccess() != nullptr) {
      return determineBitfieldAccessTypeAndWidth(bctx, access->bitfieldAccess());
    }
  } else if (identifier) {
    // identifier
    return determineIdentifierTypeAndWidth(bctx, identifier, sourceloc(identifier));
  }
  sl_assert(false);
  return t_type_nfo(UInt, 0);
}

// -------------------------------------------------

v2i Algorithm::determineAccessConstBitRange(
  siliceParser::AccessContext         *access,
  const t_combinational_block_context *bctx) const
{
  if (access->partSelect() != nullptr) {
    return determineAccessConstBitRange(access->partSelect(), bctx);
  } else if (access->bitfieldAccess() != nullptr) {
    return determineAccessConstBitRange(access->bitfieldAccess(), bctx, v2i(-1));
  } else {
    return v2i(-1); // non applicable
  }
  return v2i(-1); // non applicable
}

// -------------------------------------------------

v2i Algorithm::determineAccessConstBitRange(
  siliceParser::BitfieldAccessContext *access,
  const t_combinational_block_context *bctx,
  v2i                                  range) const
{
  auto F = m_KnownBitFields.find(access->field->getText());
  if (F == m_KnownBitFields.end()) {
    reportError(
      sourceloc(access),
      "unknown bitfield '%s'", access->field->getText().c_str());
  }
  verifyMemberBitfield(access->member->getText(), F->second);
  pair<t_type_nfo, int> ow = bitfieldMemberTypeAndOffset(F->second, access->member->getText());
  v2i new_range;
  new_range[0] = ow.second;
  new_range[1] = ow.first.width;
  if (range[0] > -1) {
    new_range[0] = new_range[0] + range[0];
    new_range[1] = range[1];
  }
  return new_range;
}

// -------------------------------------------------

v2i Algorithm::determineAccessConstBitRange(
  siliceParser::PartSelectContext     *access,
  const t_combinational_block_context *bctx) const
{
  v2i range;
  string offset;
  bool ok = isConst(access->first, offset);
  if (!ok) {
    return v2i(-1); // non applicable
  }
  string width = gatherConstValue(access->num);
  try {
    range[0] = std::stoi(offset);
    range[1] = std::stoi(width);
  } catch (...) {
    reportError(sourceloc(access),"cannot resolve part select bit range in binding");
  }
  if (access->tableAccess() != nullptr) {
    return v2i(-1); // non applicable
  } else if (access->bitfieldAccess() != nullptr) {
    return determineAccessConstBitRange(access->bitfieldAccess(), bctx, range);
  } else {
    return range;
  }
}

// -------------------------------------------------

void Algorithm::writeAlgorithmCall(antlr4::tree::ParseTree *node, std::string prefix, std::ostream& out, const t_instanced_nfo& a, siliceParser::CallParamListContext* plist, const t_combinational_block_context *bctx, const t_instantiation_context &ictx, const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const
{
  // check an algorithm is called
  Algorithm *alg = dynamic_cast<Algorithm*>(a.blueprint.raw());
  if (alg == nullptr) {
    reportError(sourceloc(node),
      "called instance '%s' is not an algorithm",
      a.instance_name.c_str());
  }
  // check for clock domain crossing
  if (a.instance_clock != m_Clock) {
    reportError(sourceloc(node),
      "algorithm instance '%s' called accross clock-domain -- not yet supported",
      a.instance_name.c_str());
  }
  // check for call on non callable
  if (a.blueprint->isNotCallable()) {
    reportError(sourceloc(node),
      "algorithm instance '%s' called while being on autorun or having only always blocks",
      a.instance_name.c_str());
  }
  // if params are empty we simply call, otherwise we set the inputs
  if (!plist->expression_0().empty()) {
    // parse parameters
    std::vector<t_call_param> matches;
    parseCallParams(plist, alg, true, bctx, matches);
    // set inputs
    int p = 0;
    for (const auto& ins : a.blueprint->inputs()) {
      if (a.boundinputs.count(ins.name) > 0) {
        reportError(sourceloc(node),
        "algorithm instance '%s' cannot be called with parameters as its input '%s' is bound",
          a.instance_name.c_str(), ins.name.c_str());
      }
      // out << FF_D << a.instance_prefix << "_" << ins.name; // NOTE: we are certain a flip-flop is produced as the algorithm is bound to the 'Q' side
      out << rewriteIdentifier(prefix, a.instance_prefix + "_" + ins.name, "", bctx, ictx, sourceloc(plist), FF_D, false, dependencies, _ff_usage);
      if (std::holds_alternative<std::string>(matches[p].what)) {
        out << " = " << rewriteIdentifier(prefix, std::get<std::string>(matches[p].what), "", bctx, ictx, sourceloc(plist), FF_Q, true, dependencies, _ff_usage);
      } else {
        out << " = " << rewriteExpression(prefix, matches[p].expression, -1 /*cannot be in repeated block*/, bctx, ictx, FF_Q, true, dependencies, _ff_usage);
      }
      out << ";" << nxl;
      ++p;
    }
  }
  // restart algorithm (pulse run low)
  out << a.instance_prefix << "_" << ALG_RUN << " = 0;" << nxl;
  /// WARNING: this does not work across clock domains!
}

// -------------------------------------------------

void Algorithm::writeAlgorithmReadback(antlr4::tree::ParseTree *node, std::string prefix, std::ostream& out, const t_instanced_nfo& a, siliceParser::CallParamListContext* plist, const t_combinational_block_context* bctx, const t_instantiation_context &ictx, t_vio_ff_usage &_ff_usage) const
{
  // check an algorithm is joined
  Algorithm *alg = dynamic_cast<Algorithm*>(a.blueprint.raw());
  if (alg == nullptr) {
    reportError(sourceloc(node),
      "joined instance '%s' is not an algorithm",
      a.instance_name.c_str());
  }
  // check for pipeline
  if (bctx->pipeline != nullptr) {
    reportError(sourceloc(node),
      "cannot join algorithm instance from a pipeline");
  }
  // check for clock domain crossing
  if (a.instance_clock != m_Clock) {
    reportError(sourceloc(node),
     "algorithm instance '%s' joined accross clock-domain -- not yet supported",
      a.instance_name.c_str());
  }
  // check for call on purely combinational
  if (alg->hasNoFSM()) {
    reportError(sourceloc(node),
      "algorithm instance '%s' joined while being state-less",
      a.instance_name.c_str());
  }
  // if params are empty we simply wait, otherwise we set the outputs
  if (!plist->expression_0().empty()) {
    // parse parameters
    std::vector<t_call_param> matches;
    parseCallParams(plist, alg, false, bctx, matches);
    // read outputs
    int p = 0;
    for (const auto& outs : a.blueprint->outputs()) {
      if (std::holds_alternative<std::string>(matches[p].what)) {
        // check if bound
        if (m_VIOBoundToBlueprintOutputs.count(std::get<std::string>(matches[p].what))) {
          reportError(sourceloc(node),
            "algorithm instance '%s', cannot store output '%s' in bound variable '%s'",
            a.instance_name.c_str(), outs.name.c_str(), std::get<std::string>(matches[p].what).c_str());
        }
        t_vio_dependencies _;
        out << rewriteIdentifier(prefix, std::get<std::string>(matches[p].what), "", bctx, ictx, sourceloc(plist), FF_D, true, _, _ff_usage);
      } else if (std::holds_alternative<siliceParser::AccessContext*>(matches[p].what)) {
        t_vio_dependencies _;
        writeAccess(prefix, out, true, std::get<siliceParser::AccessContext *>(matches[p].what), -1, bctx, ictx, FF_D, _, _ff_usage);
      } else {
        reportError(sourceloc(matches[p].expression),
          "algorithm instance '%s', invalid expression for storing output '%s'",
          a.instance_name.c_str(), outs.name.c_str());
      }
      out << " = " << WIRE << a.instance_prefix << "_" << outs.name << ";" << nxl;
      ++p;
    }
  }
}

// -------------------------------------------------

void Algorithm::writeSubroutineCall(antlr4::tree::ParseTree *node, std::string prefix, std::ostream& out, const t_subroutine_nfo *called, const t_combinational_block_context *bctx, const t_instantiation_context &ictx, siliceParser::CallParamListContext* plist, const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const
{
  if (bctx->pipeline != nullptr) {
    reportError(sourceloc(node),
      "cannot call a subroutine from a pipeline");
  }
  // parse parameters
  std::vector<t_call_param> matches;
  parseCallParams(plist, called, true, bctx, matches);
  // set inputs
  int p = 0;
  for (const auto& ins : called->inputs) {
    out << rewriteIdentifier(prefix, called->vios.at(ins), "", bctx, ictx, sourceloc(plist), FF_D, false, dependencies, _ff_usage);
    if (std::holds_alternative<std::string>(matches[p].what)) {
      out << " = " << rewriteIdentifier(prefix, std::get<std::string>(matches[p].what), "", bctx, ictx, sourceloc(plist), FF_Q, true, dependencies, _ff_usage);
    } else {
      out << " = " << rewriteExpression(prefix, matches[p].expression, -1 /*cannot be in repeated block*/, bctx, ictx, FF_Q, true, dependencies, _ff_usage);
    }
    out << ';' << nxl;
    ++p;
  }
}

// -------------------------------------------------

void Algorithm::writeSubroutineReadback(antlr4::tree::ParseTree *node, std::string prefix, std::ostream& out, const t_subroutine_nfo* called, const t_combinational_block_context* bctx, const t_instantiation_context &ictx, siliceParser::CallParamListContext* plist, t_vio_ff_usage &_ff_usage) const
{
  if (bctx->pipeline != nullptr) {
    reportError(sourceloc(node),
    "cannot join a subroutine from a pipeline");
  }
  // parse parameters
  std::vector<t_call_param> matches;
  parseCallParams(plist, called, false, bctx, matches);
  // read outputs
  int p = 0;
  for (const auto &outs : called->outputs) {
    if (std::holds_alternative<std::string>(matches[p].what)) {
      t_vio_dependencies _;
      out << rewriteIdentifier(prefix, std::get<std::string>(matches[p].what), "", bctx, ictx, sourceloc(plist), FF_D, true, _, _ff_usage);
    } else if (std::holds_alternative<siliceParser::AccessContext *>(matches[p].what)) {
      t_vio_dependencies _;
      writeAccess(prefix, out, true, std::get<siliceParser::AccessContext *>(matches[p].what), -1, bctx, ictx, FF_D, _, _ff_usage);
    } else {
      reportError(sourceloc(matches[p].expression),
        "call to subroutine '%s' invalid receiving expression for output '%s'",
        called->name.c_str(), outs.c_str());
    }
    updateFFUsage(e_Q, true, _ff_usage.ff_usage[called->vios.at(outs)]);
    out << " = " << FF_Q << prefix << called->vios.at(outs) << ';' << nxl;
    ++p;
  }
}

// -------------------------------------------------

std::tuple<t_type_nfo, int> Algorithm::writeIOAccess(
  std::string prefix, std::ostream& out, bool assigning,
  siliceParser::IoAccessContext* ioaccess, std::string suffix,
  int __id, const t_combinational_block_context* bctx, const t_instantiation_context& ictx,
  string ff,  const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const
{
  std::string base = ioaccess->base->getText();
  base = translateVIOName(base, bctx);
  if (ioaccess->IDENTIFIER().size() != 2) {
    reportError(sourceloc(ioaccess),
      "'.' access depth limited to one in current version '%s'", base.c_str());
  }
  std::string member = ioaccess->IDENTIFIER()[1]->getText();
  // find blueprint
  auto A = m_InstancedBlueprints.find(base);
  if (A != m_InstancedBlueprints.end()) {
    if (!A->second.blueprint->isInput(member) && !A->second.blueprint->isOutput(member)) {
      reportError(sourceloc(ioaccess),
        "'%s' is neither an input nor an output, instance '%s'", member.c_str(), base.c_str());
    }
    if (assigning && !A->second.blueprint->isInput(member)) {
      reportError(sourceloc(ioaccess),
        "cannot write to algorithm output '%s', instance '%s'", member.c_str(), base.c_str());
    }
    if (A->second.blueprint->isInput(member)) {
      // algorithm input
      if (A->second.boundinputs.count(member) > 0) {
        reportError(sourceloc(ioaccess),
        "cannot access bound input '%s' on instance '%s'", member.c_str(), base.c_str());
      }
      out << rewriteIdentifier(prefix, A->second.instance_prefix + "_" + member, suffix, bctx, ictx, sourceloc(ioaccess), assigning ? FF_D : ff, !assigning, dependencies, _ff_usage);
      // out << FF_D << A->second.instance_prefix << "_" << member << suffix;
      return A->second.blueprint->determineVIOTypeWidthAndTableSize(member, sourceloc(ioaccess));
    } else if (A->second.blueprint->isOutput(member)) {
      out << WIRE << A->second.instance_prefix << "_" << member << suffix;
      return A->second.blueprint->determineVIOTypeWidthAndTableSize(member, sourceloc(ioaccess));
    } else {
      sl_assert(false);
    }
  } else {
    auto G = m_VIOGroups.find(base);
    if (G != m_VIOGroups.end()) {
      verifyMemberGroup(member, G->second);
      // produce the variable name
      std::string vname = base + "_" + member;
      // write
      out << rewriteIdentifier(prefix, vname, suffix, bctx, ictx, sourceloc(ioaccess), assigning ? FF_D : ff, !assigning, dependencies, _ff_usage);
      return determineVIOTypeWidthAndTableSize(translateVIOName(vname, bctx), sourceloc(ioaccess));
    } else {
      reportError(sourceloc(ioaccess),
        "cannot find accessed base.member '%s.%s'", base.c_str(), member.c_str());
    }
  }
  sl_assert(false);
  return make_tuple(t_type_nfo(UInt, 0), 0);
}

// -------------------------------------------------

void Algorithm::writeTableAccess(
  std::string prefix, std::ostream& out, bool assigning,
  siliceParser::TableAccessContext* tblaccess, std::string suffix,
  int __id, const t_combinational_block_context *bctx, const t_instantiation_context &ictx,
  string ff, const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const
{
  suffix = "[" + rewriteExpression(prefix, tblaccess->expression_0(), __id, bctx, ictx, FF_Q, true, dependencies, _ff_usage) + "]" + suffix;
  /// TODO: if the expression can be evaluated at compile time, we could check for access validity using table_size
  if (tblaccess->ioAccess() != nullptr) {
    auto tws = writeIOAccess(prefix, out, assigning, tblaccess->ioAccess(), suffix, __id, bctx, ictx, ff, dependencies, _ff_usage);
    if (get<1>(tws) == 0) {
      reportError(sourceloc(tblaccess->ioAccess()->IDENTIFIER().back()), "trying to access a non table as a table");
    }
  } else {
    sl_assert(tblaccess->IDENTIFIER() != nullptr);
    std::string vname = tblaccess->IDENTIFIER()->getText();
    out << rewriteIdentifier(prefix, vname, suffix, bctx, ictx, sourceloc(tblaccess), assigning ? FF_D : ff, !assigning, dependencies, _ff_usage);
    // get width
    auto tws = determineIdentifierTypeWidthAndTableSize(bctx, tblaccess->IDENTIFIER(), sourceloc(tblaccess));
    if (get<1>(tws) == 0) {
      reportError(sourceloc(tblaccess->IDENTIFIER()), "trying to access a non table as a table");
    }
  }
}

// -------------------------------------------------

void Algorithm::writeBitfieldAccess(
  std::string prefix, std::ostream& out, bool assigning,
  siliceParser::BitfieldAccessContext* bfaccess, std::pair<std::string, std::string> range,
  int __id, const t_combinational_block_context* bctx, const t_instantiation_context &ictx, string ff,
  const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const
{
  // find field definition
  auto F = m_KnownBitFields.find(bfaccess->field->getText());
  if (F == m_KnownBitFields.end()) {
    reportError(sourceloc(bfaccess), "unknown bitfield '%s'", bfaccess->field->getText().c_str());
  }
  verifyMemberBitfield(bfaccess->member->getText(), F->second);
  pair<t_type_nfo, int> ow = bitfieldMemberTypeAndOffset(F->second, bfaccess->member->getText());
  sl_assert(ow.first.width > -1); // should never happen as member is checked before
  if (ow.first.base_type == Int) {
    out << "$signed(";
  }
  // create range
  /// TODO: bound checks on constant expr
  std::pair<std::string, std::string> new_range;
  new_range.first  = std::to_string(ow.second);
  new_range.second = std::to_string(ow.first.width);
  if (!range.first.empty()) {
    new_range.first  = "((" + range.first + ")+(" + new_range.first + "))";
    new_range.second = range.second;
  }
  std::string suffix = "[" + new_range.first + "+:" + new_range.second + "]";
  if (bfaccess->tableAccess() != nullptr) {
    writeTableAccess(prefix, out, assigning, bfaccess->tableAccess(), suffix, __id, bctx, ictx, ff, dependencies, _ff_usage);
  } else if (bfaccess->idOrIoAccess()->ioAccess() != nullptr) {
    writeIOAccess(prefix, out, assigning, bfaccess->idOrIoAccess()->ioAccess(), suffix, __id, bctx, ictx, ff, dependencies, _ff_usage);
  } else {
    sl_assert(bfaccess->idOrIoAccess()->IDENTIFIER() != nullptr);
    out << rewriteIdentifier(prefix, bfaccess->idOrIoAccess()->IDENTIFIER()->getText(), suffix, bctx, ictx,
      sourceloc(bfaccess->idOrIoAccess()), assigning ? FF_D : ff, !assigning, dependencies, _ff_usage);
  }
  // out << '[' << ow.second << "+:" << ow.first.width << ']';
  if (ow.first.base_type == Int) {
    out << ")";
  }
}

// -------------------------------------------------

void Algorithm::writePartSelect(std::string prefix, std::ostream& out, bool assigning, siliceParser::PartSelectContext* partsel,
  int __id, const t_combinational_block_context* bctx, const t_instantiation_context &ictx, string ff,
  const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const
{
  /// TODO: bound checks on constant expr
  std::pair<std::string, std::string> range;
  range.first  = rewriteExpression(prefix, partsel->first, __id, bctx, ictx, FF_Q, true, dependencies, _ff_usage);
  range.second = gatherConstValue(partsel->num);
  if (partsel->ioAccess() != nullptr) {
    writeIOAccess(prefix, out, assigning, partsel->ioAccess(), '[' + range.first + "+:" + range.second + ']', __id, bctx, ictx, ff, dependencies, _ff_usage);
  } else if (partsel->tableAccess() != nullptr) {
    writeTableAccess(prefix, out, assigning, partsel->tableAccess(), '[' + range.first + "+:" + range.second + ']', __id, bctx, ictx, ff, dependencies, _ff_usage);
  } else if (partsel->bitfieldAccess() != nullptr) {
    writeBitfieldAccess(prefix, out, assigning, partsel->bitfieldAccess(), range, __id, bctx, ictx, ff, dependencies, _ff_usage);
  } else {
    sl_assert(partsel->IDENTIFIER() != nullptr);
    out << rewriteIdentifier(prefix, partsel->IDENTIFIER()->getText(), '[' + range.first + "+:" + range.second + ']', bctx, ictx,
      sourceloc(partsel), assigning ? FF_D : ff, !assigning, dependencies, _ff_usage);
  }
  // out << '[' << rewriteExpression(prefix, partsel->first, __id, bctx, FF_Q, true, dependencies, _ff_usage) << "+:" << gatherConstValue(partsel->num) << ']';
  if (assigning) {
    // This is a part-select access. We assume it is partial (could be checked if const).
    // Thus the variable is likely only partially written and to be safe we tag
    // it as Q since other bits are likely read later in the execution flow.
    // This is a conservative assumption. A bit-per-bit analysis could be envisioned,
    // but for lack of it we have no other choice here to avoid generating wrong code.
    // See also issue #54.
    std::string var = determineAccessedVar(partsel, bctx);
    updateFFUsage(e_Q, true, _ff_usage.ff_usage[var]);
  }
}

// -------------------------------------------------

void Algorithm::writeAccess(std::string prefix, std::ostream& out, bool assigning, siliceParser::AccessContext* access,
  int __id, const t_combinational_block_context* bctx, const t_instantiation_context &ictx, string ff,
  const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const
{
  if (access->ioAccess() != nullptr) {
    writeIOAccess(prefix, out, assigning, access->ioAccess(), "", __id, bctx, ictx, ff, dependencies, _ff_usage);
  } else if (access->tableAccess() != nullptr) {
    writeTableAccess(prefix, out, assigning, access->tableAccess(), "", __id, bctx, ictx, ff, dependencies, _ff_usage);
  } else if (access->partSelect() != nullptr) {
    writePartSelect(prefix, out, assigning, access->partSelect(), __id, bctx, ictx, ff, dependencies, _ff_usage);
  } else if (access->bitfieldAccess() != nullptr) {
    writeBitfieldAccess(prefix, out, assigning, access->bitfieldAccess(), std::make_pair("", ""), __id, bctx, ictx, ff, dependencies, _ff_usage);
  }
}

// -------------------------------------------------

void Algorithm::writeAssignement(std::string prefix, std::ostream& out,
  const t_instr_nfo& a,
  siliceParser::AccessContext *access,
  antlr4::tree::TerminalNode* identifier,
  siliceParser::Expression_0Context *expression_0,
  const t_combinational_block_context *bctx, const t_instantiation_context &ictx,
  string ff, const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const
{
  // verify type of assignement
  auto assign = dynamic_cast<siliceParser::AssignmentContext *>(a.instr);
  if (assign) {
    if (assign->OUTASSIGN_AFTER() != nullptr) {
      // check in pipeline
      if (bctx->pipeline == nullptr) {
        reportError(sourceloc(a.instr),"cannot use outside of pipeline assign (^=) if not inside a pipeline");
      }
    } else if (assign->OUTASSIGN_BEFORE() != nullptr) {
      // check in pipeline
      if (bctx->pipeline == nullptr) {
        reportError(sourceloc(a.instr), "cannot use outside of pipeline assign (v=) if not inside a pipeline");
      }
    }
  }
  // write access
  if (access) {
    // table, output or bits
    if (isInput(determineAccessedVar(access, bctx))) {
      reportError(sourceloc(a.instr),
        "cannot assign a value to an input of the algorithm, input '%s'",
        determineAccessedVar(access, bctx).c_str());
    }
    writeAccess(prefix, out, true, access, a.__id, bctx, ictx, ff, dependencies, _ff_usage);
  } else {
    sl_assert(identifier != nullptr);
    // variable
    if (isInput(identifier->getText())) {
      reportError(sourceloc(a.instr),
        "cannot assign a value to an input of the algorithm, input '%s'",
        identifier->getText().c_str());
    }
    out << rewriteIdentifier(prefix, identifier->getText(), "", bctx, ictx, sourceloc(identifier), FF_D, false, dependencies, _ff_usage);
  }
  out << " = " + rewriteExpression(prefix, expression_0, a.__id, bctx, ictx, ff, true, dependencies, _ff_usage);
  out << ';' << nxl;

}

// -------------------------------------------------

void Algorithm::writeAssert(std::string prefix,
                            std::ostream &out,
                            const t_instr_nfo &a,
                            siliceParser::Expression_0Context *expression_0,
                            const t_combinational_block_context *bctx,
                            const t_instantiation_context &ictx,
                            std::string ff,
                            const t_vio_dependencies &dependencies,
                            t_vio_ff_usage &_ff_usage) const
{
  auto const &[file, line] = s_LuaPreProcessor->lineAfterToFileAndLineBefore(
    ParsingContext::rootContext(a.instr),
    (int)expression_0->getStart()->getLine());
  std::string silice_position = file + ":" + std::to_string(line);

  out << "assert(($initstate || " << m_Reset << ") || (" << rewriteExpression(prefix, expression_0, a.__id, bctx, ictx, ff, true, dependencies, _ff_usage) << ")); //%" << silice_position << nxl;
}

// -------------------------------------------------

void Algorithm::writeAssume(std::string prefix,
                            std::ostream &out,
                            const t_instr_nfo &a,
                            siliceParser::Expression_0Context *expression_0,
                            const t_combinational_block_context *bctx,
                            const t_instantiation_context &ictx,
                            std::string ff,
                            const t_vio_dependencies &dependencies,
                            t_vio_ff_usage &_ff_usage) const
{
  auto const &[file, line] = s_LuaPreProcessor->lineAfterToFileAndLineBefore(
    ParsingContext::rootContext(a.instr),
    (int)expression_0->getStart()->getLine());
  std::string silice_position = file + ":" + std::to_string(line);

  out << "assume(($initstate || " << m_Reset << ") || (" << rewriteExpression(prefix, expression_0, a.__id, bctx, ictx, ff, true, dependencies, _ff_usage) << ")); //%" << silice_position << nxl;
}

// -------------------------------------------------

void Algorithm::writeRestrict(std::string prefix,
                              std::ostream &out,
                              const t_instr_nfo &a,
                              siliceParser::Expression_0Context *expression_0,
                              const t_combinational_block_context *bctx,
                              const t_instantiation_context &ictx,
                              std::string ff,
                              const t_vio_dependencies &dependencies,
                              t_vio_ff_usage &_ff_usage) const
{
  auto const &[file, line] = s_LuaPreProcessor->lineAfterToFileAndLineBefore(
    ParsingContext::rootContext(a.instr),
    (int)expression_0->getStart()->getLine());
  std::string silice_position = file + ":" + std::to_string(line);

  out << "restrict(($initstate || " << m_Reset << ") || (" << rewriteExpression(prefix, expression_0, a.__id, bctx, ictx, ff, true, dependencies, _ff_usage) << ")); //%" << silice_position << nxl;
}

// -------------------------------------------------

void Algorithm::writeCover(std::string prefix,
                           std::ostream &out,
                           const t_instr_nfo &a,
                           siliceParser::Expression_0Context *expression_0,
                           const t_combinational_block_context *bctx,
                           const t_instantiation_context &ictx,
                           std::string ff,
                           const t_vio_dependencies &dependencies,
                           t_vio_ff_usage &_ff_usage) const
{
  auto const &[file, line] = s_LuaPreProcessor->lineAfterToFileAndLineBefore(
    ParsingContext::rootContext(a.instr),
    (int)expression_0->getStart()->getLine());
  std::string silice_position = file + ":" + std::to_string(line);

  out << "cover(" << rewriteExpression(prefix, expression_0, a.__id, bctx, ictx, ff, true, dependencies, _ff_usage) << "); //%" << silice_position << nxl;
}

// -------------------------------------------------

void Algorithm::writeWireAssignements(
  std::string prefix, std::ostream &out, const t_instantiation_context &ictx,
  t_vio_dependencies& _dependencies, t_vio_ff_usage &_ff_usage, bool first_pass) const
{
  for (const auto &a : m_WireAssignments) {
    auto alw = dynamic_cast<siliceParser::AlwaysAssignedContext *>(a.second.instr);
    sl_assert(alw != nullptr);
    sl_assert(alw->IDENTIFIER() != nullptr);
    // -> determine assigned var
    string var = translateVIOName(alw->IDENTIFIER()->getText(), &a.second.block->context);
    // double check that this always assignment is on a wire var
    bool wire_assign = false;
    if (m_VarNames.count(var) > 0) {
      wire_assign = (m_Vars.at(m_VarNames.at(var)).usage == e_Wire);
    }
    sl_assert(wire_assign);
    // skip if not used
    if (m_Vars.at(m_VarNames.at(var)).access == e_NotAccessed) {
      continue;
    }
    // type of assignment
    bool d_else_q = (alw->ALWSASSIGNDBL() == nullptr && alw->LDEFINEDBL() == nullptr);
    out << "assign ";
    writeAssignement(prefix, out, a.second, alw->access(), alw->IDENTIFIER(), alw->expression_0(), &a.second.block->context, ictx,
      d_else_q ? FF_D : FF_Q,
      _dependencies, _ff_usage);
    // update dependencies
    t_vio_dependencies no_dependencies = _dependencies;
    updateAndCheckDependencies(_dependencies, a.second.instr, &a.second.block->context);
    // update usage of dependencies to q if q is used
    if (!d_else_q) {
      for (const auto &dep : _dependencies.dependencies.at(var)) {
        updateFFUsage(e_Q, true, _ff_usage.ff_usage[dep]);
      }
      // ignore dependencies if reading from Q: we can ignore them safely
      // as the wire does not contribute to creating combinational cycles
      _dependencies = no_dependencies;
      /// TODO FIXME really, what if one of the dependecies was a <:, input or bound wire?
    }
  }
  out << nxl;
}

// -------------------------------------------------

void Algorithm::writeVerilogDeclaration(std::ostream &out, const t_instantiation_context &ictx, std::string base, const t_var_nfo &v, std::string postfix) const
{
  out << base << " " << typeString(varType(v,ictx)) << " " << varBitRange(v,ictx) << " " << postfix << ';' << nxl;
}

// -------------------------------------------------

void Algorithm::writeVerilogDeclaration(const Blueprint *bp, std::ostream &out, const t_instantiation_context &ictx, std::string base, const t_var_nfo &v, std::string postfix) const
{
  out << base << " " << typeString(bp->varType(v, ictx)) << " " << bp->varBitRange(v, ictx) << " " << postfix << ';' << nxl;
}

// -------------------------------------------------

void Algorithm::writeConstDeclarations(std::string prefix, std::ostream& out,const t_instantiation_context &ictx) const
{
  for (const auto& v : m_Vars) {
    if (v.usage != e_Const) continue;
    if (v.table_size == 0) {
      writeVerilogDeclaration(out, ictx, "wire", v, string(FF_CST) + prefix + v.name);
    } else {
      writeVerilogDeclaration(out, ictx, "wire", v, string(FF_CST) + prefix + v.name + '[' + std::to_string(v.table_size - 1) + ":0]");
    }
    if (!v.do_not_initialize) {
      if (v.table_size == 0) {
        out << "assign " << FF_CST << prefix << v.name << " = " << varInitValue(v,ictx) << ';' << nxl;
      } else {
        sl_assert(v.type_nfo.base_type != Parameterized);
        ForIndex(i, v.init_values.size()) {
          out << "assign " << FF_CST << prefix << v.name << '[' << i << ']' << " = " << v.init_values[i] << ';' << nxl;
        }
      }
    } else if (CONFIG.keyValues().count("reg_init_zero")) {
      if (v.table_size == 0) {
        out << "assign " << FF_CST << prefix << v.name << " = 0;" << nxl;
      } else {
        sl_assert(v.type_nfo.base_type != Parameterized);
        ForIndex(i, v.init_values.size()) {
          out << "assign " << FF_CST << prefix << v.name << '[' << i << ']' << " = 0;" << nxl;
        }
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::writeTempDeclarations(std::string prefix, std::ostream& out, const t_instantiation_context &ictx) const
{
  for (const auto& v : m_Vars) {
    if (v.usage != e_Temporary) continue;
    if (v.table_size == 0) {
      writeVerilogDeclaration(out, ictx, "reg", v, string(FF_TMP) + prefix + v.name);
    } else {
      writeVerilogDeclaration(out, ictx, "reg", v, string(FF_TMP) + prefix + v.name + '[' + std::to_string(v.table_size - 1) + ":0]");
    }
  }
  for (const auto &v : m_Outputs) {
    if (v.usage != e_Temporary) continue;
    writeVerilogDeclaration(out, ictx, "reg", v, string(FF_TMP) + prefix + v.name);
  }
}

// -------------------------------------------------

void Algorithm::writeWireDeclarations(std::string prefix, std::ostream& out, const t_instantiation_context &ictx) const
{
  for (const auto& v : m_Vars) {
    if ((v.usage == e_Bound && v.access == e_ReadWriteBinded) || v.usage == e_Wire) {
      // skip if not used
      if (v.access == e_NotAccessed) {
        continue;
      }
      if (v.table_size == 0) {
        writeVerilogDeclaration(out, ictx, "wire", v, string(WIRE) + prefix + v.name);
      } else {
        writeVerilogDeclaration(out, ictx, "wire", v, string(WIRE) + prefix + v.name + '[' + std::to_string(v.table_size - 1) + ":0]");
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::writeFlipFlopDeclarations(std::string prefix, std::ostream& out, const t_instantiation_context &ictx) const
{
  out << nxl;
  // flip-flops for vars
  for (const auto& v : m_Vars) {
    if (v.usage != e_FlipFlop) continue;
    if (v.table_size == 0) {
      std::string init;
      if (v.init_at_startup && !v.init_values.empty()) {
        init = " = " + v.init_values[0];
      } else if (CONFIG.keyValues().count("reg_init_zero")) {
        init = " = 0";
      }
      writeVerilogDeclaration(out, ictx, "reg", v, string(FF_D) + prefix + v.name + init);
      writeVerilogDeclaration(out, ictx, (v.attribs.empty() ? "" : (v.attribs + "\n")) + "reg", v, string(FF_Q) + prefix + v.name + init);
    } else {
      writeVerilogDeclaration(out, ictx, "reg", v, string(FF_D) + prefix + v.name + '[' + std::to_string(v.table_size - 1) + ":0]");
      writeVerilogDeclaration(out, ictx, (v.attribs.empty() ? "" : (v.attribs + "\n")) + "reg", v, string(FF_Q) + prefix + v.name + '[' + std::to_string(v.table_size - 1) + ":0]");
    }
  }
  // flip-flops for outputs
  for (const auto& v : m_Outputs) {
    if (v.usage != e_FlipFlop) continue;
    sl_assert(v.table_size == 0);
    std::string init;
    if (v.init_at_startup && !v.init_values.empty()) {
      init = " = " + v.init_values[0];
    } else if (CONFIG.keyValues().count("reg_init_zero")) {
      init = " = 0";
    }
    writeVerilogDeclaration(out, ictx, "reg", v, string(FF_D) + prefix + v.name + init);
    writeVerilogDeclaration(out, ictx, "reg", v, string(FF_Q) + prefix + v.name + init);
  }
  // state machine index
  if (!hasNoFSM()) {
    if (!m_OneHot) {
      out << "reg  [" << stateWidth() - 1 << ":0] " FF_D << prefix << ALG_IDX "," FF_Q << prefix << ALG_IDX << " = " << toFSMState(terminationState()) << ";" << nxl;
    } else {
      out << "reg  [" << maxState() - 1 << ":0] " FF_D << prefix << ALG_IDX "," FF_Q << prefix << ALG_IDX << " = " << toFSMState(terminationState()) << ";" << nxl;
    }
    // sub-state indices (one-hot)
    for (auto b : m_Blocks) {
      if (b->num_sub_states > 1) {
        out << "reg  [" << width(b->num_sub_states) - 1 << ":0] " FF_D << prefix << b->block_name << '_' << ALG_IDX "," FF_Q << prefix << b->block_name << '_' << ALG_IDX << ";" << nxl;
      }
    }
    // autorun
    if (m_AutoRun) {
      out << "reg  " << prefix << ALG_AUTORUN << " = 0;" << nxl;
    }
  }
  // state machine caller id (subroutine)
  if (!doesNotCallSubroutines()) {
    out << "reg  [" << (width(m_SubroutineCallerNextId) - 1) << ":0] " FF_D << prefix << ALG_CALLER << "," FF_Q << prefix << ALG_CALLER << ";" << nxl;
    // per-subroutine caller id backup (subroutine making nested calls)
    for (auto sub : m_Subroutines) {
      if (sub.second->contains_calls) {
        out << "reg  [" << (width(m_SubroutineCallerNextId) - 1) << ":0] " FF_D << prefix << sub.second->name << "_" << ALG_CALLER << "," FF_Q << prefix << sub.second->name << "_" << ALG_CALLER << ";" << nxl;
      }
    }
  }
  // state machine run for instanced algorithms
  for (const auto& iaiordr : m_InstancedBlueprintsInDeclOrder) {
    const auto &ia = m_InstancedBlueprints.at(iaiordr);
    Algorithm *alg = dynamic_cast<Algorithm*>(ia.blueprint.raw());
    if (alg != nullptr) {
      if (!alg->isNotCallable()) {
        out << "reg  " << ia.instance_prefix + "_" ALG_RUN << " = 0;" << nxl;
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::writeVarFlipFlopUpdate(std::string prefix, std::string reset, std::ostream &out, const t_instantiation_context &ictx, const t_var_nfo &v) const
{
  std::string init_cond = reset;
  if (reset.empty()) {
    init_cond = "";
  } else if (v.init_at_startup || v.do_not_initialize) {
    init_cond = "";
  } else if (!isNotCallable()) {
    init_cond = reset + (" | ~" ALG_INPUT "_" ALG_RUN);
  } else {
    init_cond = reset;
  }
  std::string d_var = FF_D + prefix + v.name;
  if (!v.pipeline_prev_name.empty()) {
    bool found = false;
    auto pv    = getVIODefinition(v.pipeline_prev_name, found);
    sl_assert(found);
    d_var      = (pv.usage == e_Temporary) ? (FF_TMP + prefix + v.pipeline_prev_name) : (FF_D + prefix + v.pipeline_prev_name);
  }
  if (v.table_size == 0) {
    // not a table
    string initv = varInitValue(v, ictx);
    if (!init_cond.empty() && !initv.empty()) {
      out << FF_Q << prefix << v.name << " <= (" << init_cond << ") ? " << initv << " : " << d_var << ';' << nxl;
    } else {
      out << FF_Q << prefix << v.name << " <= " << d_var << ';' << nxl;
    }
  } else {
    // table
    sl_assert(v.type_nfo.base_type != Parameterized);
    ForIndex(i, v.table_size) {
      if (!init_cond.empty()) {
        out << FF_Q << prefix << v.name << "[" << i << "] <= (" << init_cond << ") ? " << v.init_values[i] << " : " << d_var << "[" << i << "];" << nxl;
      } else {
        out << FF_Q << prefix << v.name << "[" << i << "] <= " << d_var << "[" << i << "];" << nxl;
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::writeFlipFlops(std::string prefix, std::ostream& out, const t_instantiation_context &ictx) const
{
  // output flip-flop init and update on clock
  out << nxl;
  std::string clock = m_Clock;
  if (m_Clock != ALG_CLOCK) {
    // in this case, clock has to be bound to a module/algorithm output
    /// TODO: is this over-constrained? could it also be a variable?
    auto C = m_VIOBoundToBlueprintOutputs.find(m_Clock);
    if (C == m_VIOBoundToBlueprintOutputs.end()) {
      reportError(t_source_loc(), "algorithm '%s', clock is not bound to a module or algorithm output", m_Name.c_str());
    }
    clock = C->second;
  }

  out << "always @(posedge " << clock << ") begin" << nxl;

  // determine var reset condition
  std::string reset = m_Reset;
  if (m_Reset != ALG_RESET) {
    // in this case, reset has to be bound to a module/algorithm output
    /// TODO: is this over-constrained? could it also be a variable?
    auto R = m_VIOBoundToBlueprintOutputs.find(m_Reset);
    if (R == m_VIOBoundToBlueprintOutputs.end()) {
      reportError(t_source_loc(), "algorithm '%s', reset is not bound to a module or algorithm output", m_Name.c_str());
    }
    reset = R->second;
  }
  for (const auto &v : m_Vars) {
    if (v.usage != e_FlipFlop) continue;
    writeVarFlipFlopUpdate(prefix, reset, out, ictx, v);
  }
  for (const auto &v : m_Outputs) {
    if (v.usage != e_FlipFlop) continue;
    writeVarFlipFlopUpdate(prefix, reset, out, ictx, v);
  }
  if (!hasNoFSM()) {
    std::string init_cond;
    if (!isNotCallable()) {
      init_cond = reset + (" | ~" ALG_INPUT "_" ALG_RUN);
    } else {
      init_cond = reset;
    }
    // state machine index
    out << FF_Q << prefix << ALG_IDX " <= " << reset << " ? " << toFSMState(terminationState()) << " : ";
    if (m_AutoRun) { // NOTE: same as isNotCallable() since hasNoFSM() is false
        out << "( ~" << prefix << ALG_AUTORUN << " ? " << toFSMState(entryState());
    } else {
        out << "( ~" << ALG_INPUT "_" ALG_RUN << " ? " << toFSMState(entryState());
    }
    out << " : " << FF_D << prefix << ALG_IDX  << ");" << nxl;
    if (m_AutoRun) {
      out << prefix << ALG_AUTORUN << " <= " << reset << " ? 0 : 1;" << nxl;
    }
    // sub-states indices
    for (auto b : m_Blocks) {
      if (b->num_sub_states > 1) {
        out << FF_Q << prefix << b->block_name << '_' << ALG_IDX " <= (" << init_cond << ") ? "
          << " 0 "
          << " : "
          << FF_D << prefix << b->block_name << '_' << ALG_IDX << ';' << nxl;
      }
    }
    // caller ids for subroutines
    if (!doesNotCallSubroutines()) {
      out << FF_Q << prefix << ALG_CALLER " <= " FF_D << prefix << ALG_CALLER ";" << nxl;
      for (auto sub : m_Subroutines) {
        if (sub.second->contains_calls) {
          out << FF_Q << prefix << sub.second->name << "_" << ALG_CALLER " <= " FF_D << prefix << sub.second->name << "_" << ALG_CALLER ";" << nxl;
        }
      }
    }
  }
  if (!hasNoFSM()) {
    for (const auto &chk : m_PastChecks) {
      auto B = m_State2Block.find(chk.targeted_state);
      if (B == m_State2Block.end())
        reportError(sourceloc(chk.ctx), "State named %s not found", chk.targeted_state.c_str());
      if (!B->second->is_state)
        reportError(sourceloc(chk.ctx), "State named %s does not exist", chk.targeted_state.c_str());
      auto const &[file, line] = s_LuaPreProcessor->lineAfterToFileAndLineBefore(
        ParsingContext::rootContext(chk.ctx),
        (int)chk.ctx->getStart()->getLine());
      std::string silice_position = file + ":" + std::to_string(line);
      const std::string inState = chk.current_state ? "(" FF_Q + prefix + ALG_IDX + " == " + std::to_string(chk.current_state->state_id) + ")" : "0";
      std::string condition = "(" + inState + " && !" + reset;
      if (!isNotCallable()) {
        condition = condition + " && " + ALG_INPUT "_" ALG_RUN;
      }
      condition = condition + " && !$initstate)";
      out << "assert(!" << condition << " || $past(" << FF_Q << prefix << ALG_IDX << ", " << chk.cycles_count << ") == " << B->second->state_id << "); //%" << silice_position << nxl;
    }
  }

  for (const auto &chk : m_StableChecks) {
    t_vio_dependencies _deps;
    t_vio_ff_usage _ff_usage;
    std::string silice_position;
    if (chk.isAssumption) {
      auto const &[file, line] = s_LuaPreProcessor->lineAfterToFileAndLineBefore(
        ParsingContext::rootContext(chk.ctx.assume_ctx), (int)chk.ctx.assume_ctx->getStart()->getLine());
      silice_position = file + ":" + std::to_string(line);
    } else {
      auto const &[file, line] = s_LuaPreProcessor->lineAfterToFileAndLineBefore(
        ParsingContext::rootContext(chk.ctx.assert_ctx), (int)chk.ctx.assert_ctx->getStart()->getLine());
      silice_position = file + ":" + std::to_string(line);
    }
    const std::string inState = chk.current_state ? "(" FF_Q + prefix + ALG_IDX + " == " + std::to_string(chk.current_state->state_id) + ")" : "0";
    std::string condition = "(" + inState + " && !" + reset;
    if (!isNotCallable()) {
      condition = condition + " && " + ALG_INPUT "_" ALG_RUN;
    }
    condition = condition + " && !$initstate)";
    out << (chk.isAssumption ? "assume" : "assert") << "(!" << condition
        << " || $stable(" << rewriteExpression(prefix, (chk.isAssumption ? chk.ctx.assume_ctx->expression_0() : chk.ctx.assert_ctx->expression_0()), 0, nullptr, ictx, FF_Q, true, _deps, _ff_usage) << ")); //%" << silice_position << nxl;
  }

  for (auto const &chk : m_StableInputChecks) {
    auto const &[file, line] = s_LuaPreProcessor->lineAfterToFileAndLineBefore(
      ParsingContext::rootContext(chk.ctx), (int)chk.ctx->getStart()->getLine());
    std::string silice_position = file + ":" + std::to_string(line);
    std::string condition = "(!" + reset;
    if (!isNotCallable()) {
      condition = condition + " && " + ALG_INPUT "_" ALG_RUN;
    }
    condition = condition + " && !$initstate)";
    out << "assume(!" << condition << " || $stable(" << encapsulateIdentifier(chk.varName, true, ALG_INPUT "_" + chk.varName, "") << ")); //%" << silice_position << nxl;
  }

  out << "end" << nxl;
}

// -------------------------------------------------

void Algorithm::writeVarFlipFlopCombinationalUpdate(std::string prefix, std::ostream& out, const t_var_nfo& v) const
{
  if (v.table_size == 0) {
    out << FF_D << prefix << v.name << " = " << FF_Q << prefix << v.name << ';' << nxl;
  } else {
    ForIndex(i, v.table_size) {
      out << FF_D << prefix << v.name << '[' << i << "] = " << FF_Q << prefix << v.name << '[' << i << "];" << nxl;
    }
  }
}

// -------------------------------------------------

void Algorithm::writeCombinationalAlwaysPre(
  std::string prefix,  std::ostream& out,
  const                t_instantiation_context& ictx,
  t_vio_dependencies& _always_dependencies,
  t_vio_ff_usage&     _ff_usage,
  t_vio_dependencies& _post_dependencies) const
{
  // flip-flops
  for (const auto& v : m_Vars) {
    if (v.usage != e_FlipFlop) continue;
    writeVarFlipFlopCombinationalUpdate(prefix, out, v);
  }
  for (const auto& v : m_Outputs) {
    if (v.usage != e_FlipFlop) continue;
    writeVarFlipFlopCombinationalUpdate(prefix, out, v);
  }
  if (!hasNoFSM()) {
    // state machine index
    out << FF_D << prefix << ALG_IDX " = " FF_Q << prefix << ALG_IDX << ';' << nxl;
    // sub-states indices
    for (auto b : m_Blocks) {
      if (b->num_sub_states > 1) {
        out << FF_D << prefix << b->block_name << '_' << ALG_IDX " = " FF_Q << prefix << b->block_name << '_' << ALG_IDX << ';' << nxl;
      }
    }
    // caller ids for subroutines
    if (!doesNotCallSubroutines()) {
      out << FF_D << prefix << ALG_CALLER " = " FF_Q << prefix << ALG_CALLER ";" << nxl;
      for (auto sub : m_Subroutines) {
        if (sub.second->contains_calls) {
          out << FF_D << prefix << sub.second->name << "_" << ALG_CALLER " = " FF_Q << prefix << sub.second->name << "_" << ALG_CALLER ";" << nxl;
        }
      }
    }
  }
  // instanced algorithms run, maintain high
  for (const auto& iaiordr : m_InstancedBlueprintsInDeclOrder) {
    const auto &ia = m_InstancedBlueprints.at(iaiordr);
    Algorithm *alg = dynamic_cast<Algorithm*>(ia.blueprint.raw());
    if (alg != nullptr) {
      if (!alg->isNotCallable()) {
        out << ia.instance_prefix + "_" ALG_RUN " = 1;" << nxl;
      }
    }
  }
  // instanced blueprints output bindings with wires
  // NOTE: could this be done with assignments (see Algorithm::writeAsModule) ?
  for (const auto& iaiordr : m_InstancedBlueprintsInDeclOrder) {
    const auto &ia = m_InstancedBlueprints.at(iaiordr);
    for (auto b : ia.bindings) {
      if (b.dir == e_Right) { // output
        if (m_VarNames.find(bindingRightIdentifier(b)) != m_VarNames.end()) {
          // bound to variable, the variable is replaced by the output wire
          auto usage = m_Vars.at(m_VarNames.at(bindingRightIdentifier(b))).usage;
          sl_assert(usage == e_Bound);
          // check that this is not a table member binding
          if (std::holds_alternative<siliceParser::AccessContext*>(b.right)) {
            auto access = std::get<siliceParser::AccessContext*>(b.right);
            if (access->tableAccess() != nullptr) { // tableAccess is the only one not supported
              reportError(sourceloc(access), "binding an output to a table entry is currently unsupported");
            }
          }
        } else if (m_OutputNames.find(bindingRightIdentifier(b)) != m_OutputNames.end()) {
          // bound to an algorithm output
          auto usage = m_Outputs.at(m_OutputNames.at(bindingRightIdentifier(b))).usage;
          if (usage == e_FlipFlop) {
            // the output is a flip-flop, copy from the wire
            sl_assert(std::holds_alternative<std::string>(b.right));
            out << FF_D << prefix + bindingRightIdentifier(b) + " = " + WIRE + ia.instance_prefix + "_" + b.left << ';' << nxl;
          }
          // else, the output is replaced by the wire
        }
      }
    }
  }
  // always before block
  std::queue<size_t> q;
  std::set<v2i> lines;
  ostringstream ostr; // write in a string as we might have to interleave temp init /before/ depending on ff_usage
  writeStatelessBlockGraph(prefix, ostr, ictx, &m_AlwaysPre, nullptr, q, _always_dependencies, _ff_usage, _post_dependencies, lines);
  clearNoLatchFFUsage(_ff_usage);
  // reset any temp variables that could result in a latch being created
  // these are temp vars that have not been touched by m_AlwaysPre or only partially so
  // NOTE: icarus simulation does not like the double change which trigger @always events
  //       so I now filter these assignments which would normally have no effect
  for (const auto &v : m_Vars) {
    if (v.usage != e_Temporary) continue;
    if (_ff_usage.ff_usage.count(v.name) != 0) {
      if (_ff_usage.ff_usage[v.name] != e_D) {
        out << FF_TMP << prefix << v.name << " = 0;" << nxl;
      }
    } else {
      out << FF_TMP << prefix << v.name << " = 0;" << nxl;
    }
  }
  for (const auto &v : m_Outputs) {
    if (v.usage != e_Temporary) continue;
    if (_ff_usage.ff_usage.count(v.name) != 0) {
      if (_ff_usage.ff_usage[v.name] != e_D) {
        out << FF_TMP << prefix << v.name << " = 0;" << nxl;
      }
    } else {
      out << FF_TMP << prefix << v.name << " = 0;" << nxl;
    }
  }
  // output always block
  out << ostr.str();
}

// -------------------------------------------------

void Algorithm::pushState(const t_combinational_block* b, std::queue<size_t>& _q) const
{
  if (b->is_state) {
    size_t rn = fastForward(b)->id;
    _q.push(rn);
  }
}

// -------------------------------------------------

void Algorithm::writeCombinationalStates(
  std::string prefix, std::ostream &out,
  const t_instantiation_context& ictx,
  const t_vio_dependencies&      always_dependencies,
  t_vio_ff_usage&                _ff_usage,
  t_vio_dependencies&            _post_dependencies) const
{
  vector<t_vio_ff_usage> ff_usages;
  unordered_set<size_t>  produced;
  queue<size_t>          q;
  q.push(0); // starts at 0
  // states
  if (!m_OneHot) {
    out << "(* full_case *)" << nxl;
    out << "case (" << FF_Q << prefix << ALG_IDX << ")" << nxl;
  } else {
    out << "(* parallel_case, full_case *)" << nxl;
    out << "case (1'b1)" << nxl;
  }
  // go ahead!
  while (!q.empty()) {
    size_t bid = q.front();
    const t_combinational_block *b = m_Id2Block.at(bid);
    sl_assert(b->state_id > -1);
    q.pop();
    // done already?
    if (produced.find(bid) == produced.end()) {
      produced.insert(bid);
    } else {
      // yes: skip
      continue;
    }
    // begin state
    if (!m_OneHot) {
      out << toFSMState(b->state_id) << ": begin" << nxl;
    } else {
      out << FF_Q << prefix << ALG_IDX << '[' << b->state_id << "]: begin" << nxl;
    }
    // track source code lines for reporting
    set<v2i> lines;
    // if state contains sub-state
    if (b->num_sub_states > 1) {
      // by default stay in this state
      out << FF_D << prefix << ALG_IDX << " = " << b->state_id << ';' << nxl;
      // produce a local FSM for the sequence
      // out << "(* parallel_case, full_case *)" << nxl;
      // out << "case (1'b1)" << nxl;
      out << "case (" << FF_Q << prefix << b->block_name << '_' << ALG_IDX << ")" << nxl;
      const t_combinational_block *cur = b;
      int sanity = 0;
      while (cur) {
        // write sub-state
        // -> case value
        //out << FF_Q << prefix << b->block_name << '_' << ALG_IDX << '[' << cur->sub_state_id << ']'
        out << cur->sub_state_id
          << ": begin" << nxl;
        // -> track dependencies, starting with those of always block
        t_vio_dependencies depds = always_dependencies;
        // -> write block instructions
        ff_usages.push_back(_ff_usage);
        writeStatelessBlockGraph(prefix, out, ictx, cur, nullptr, q, depds, ff_usages.back(), _post_dependencies, lines);
        clearNoLatchFFUsage(ff_usages.back());
        // -> goto next
        if (cur->sub_state_id == b->num_sub_states - 1) {
          // -> if last, reinit local index
          // out << FF_D << prefix << b->block_name << '_' << ALG_IDX " = " << b->num_sub_states << "'b1";
          out << FF_D << prefix << b->block_name << '_' << ALG_IDX " = " << "0";
        } else {
          // -> next
          /*out << FF_D << prefix << b->block_name << '_' << ALG_IDX " = " << b->num_sub_states << "'b";
          ForRangeReverse(i, b->num_sub_states - 1, 0) {
            out << (i == (cur->sub_state_id + 1) ? '1' : '0');
          }*/
          out << FF_D << prefix << b->block_name << '_' << ALG_IDX " = " << cur->sub_state_id + 1;
        }
        out << ';' << nxl;
        // -> close state
        out << "end" << nxl;
#if 0
        /// DEBUG
        for (auto ff : ff_usages.back().ff_usage) {
          out << "// " << ff.first << " ";
          if (ff.second & e_D) {
            out << "D";
          }
          if (ff.second & e_Q) {
            out << "Q";
          }
          out << nxl;
        }
#endif
        // keep going
        std::set<t_combinational_block *> leaves;
        findNonCombinationalLeaves(cur, leaves);
        ++sanity;
        if (leaves.size() == 1) {
          cur = *leaves.begin();
          if (!cur->is_sub_state) {
            break;
          }
        } else {
          break;
        }
      }
      sl_assert(sanity == b->num_sub_states);
      // closing sub-state local FSM
      out << "default: begin end" << nxl; // -> should never be reached
      out << "endcase" << nxl;
    } else {
      // track dependencies, starting with those of always block
      t_vio_dependencies depds = always_dependencies;
      // write block instructions
      ff_usages.push_back(_ff_usage);
      writeStatelessBlockGraph(prefix, out, ictx, b, nullptr, q, depds, ff_usages.back(), _post_dependencies, lines);
      clearNoLatchFFUsage(ff_usages.back());
#if 0
      /// DEBUG
      for (auto ff : ff_usages.back().ff_usage) {
        out << "// " << ff.first << " ";
        if (ff.second & e_D) {
          out << "D";
        }
        if (ff.second & e_Q) {
          out << "Q";
        }
        out << nxl;
      }
#endif
    }
    // close state
    out << "end" << nxl;
    // FSM report
    if (m_ReportingEnabled) {
      std::ofstream freport(fsmReportName(), std::ios_base::app);
      freport << (ictx.instance_name.empty() ? "__main" : ictx.instance_name) << " ";
      freport << toFSMState(b->state_id) << " ";
      freport << ' ' << lines.size() << ' ';
      for (auto l : lines) {
        if (l[0] == l[1]) {
          freport << l[0] << " ";
        } else {
          freport << l[0] << ',' << l[1] << " ";
        }
      }
      freport << nxl;
    }
  }
  // combine all ff usages
  combineFFUsageInto(nullptr,_ff_usage, ff_usages, _ff_usage);
  // initiate termination sequence
  // -> termination state
  {
    if (!m_OneHot) {
      out << toFSMState(terminationState()) << ": begin // end of " << nxl;
    } else {
      out << FF_Q << prefix << ALG_IDX << '[' << terminationState() << "]: begin // end of " << nxl;
    }
    out << "end" << nxl;
  }
  // default: internal error, should never happen
  {
    out << "default: begin " << nxl
        << FF_D << prefix << ALG_IDX " = {" << stateWidth() << "{1'bx}};" << nxl
        << "`ifdef FORMAL" << nxl
        << "assume(0);" << nxl
        << "`endif" << nxl
        << " end" << nxl;
  }
  out << "endcase" << nxl;
}

// -------------------------------------------------

v2i Algorithm::instructionLines(antlr4::tree::ParseTree *instr, const t_instantiation_context &ictx) const
{
  auto tk_start = getToken(instr, instr->getSourceInterval(), false);
  auto tk_end   = getToken(instr, instr->getSourceInterval(), true);
  if (tk_start && tk_end) {
    std::pair<std::string, int> fl_start = getTokenSourceFileAndLine(instr, tk_start);
    std::pair<std::string, int> fl_end = getTokenSourceFileAndLine(instr, tk_end);
    return v2i(fl_start.second, fl_end.second);
  }
  return v2i(-1);
}

// -------------------------------------------------

void Algorithm::writeBlock(std::string prefix, std::ostream &out, const t_instantiation_context &ictx, const t_combinational_block *block, t_vio_dependencies &_dependencies, t_vio_ff_usage &_ff_usage, std::set<v2i>& _lines) const
{
  out << "// " << block->block_name;
  if (block->context.subroutine) {
    out << " (" << block->context.subroutine->name << ')';
  }
  out << nxl;
  // block variable initialization
  if (!block->initialized_vars.empty() && block->block_name != "_top") {
    out << "// var inits" << nxl;
    writeVarInits(prefix, out, ictx, block->initialized_vars, _dependencies, _ff_usage);
    out << "// --" << nxl;
  }
  for (const auto &a : block->instructions) {
    // add to lines
    if (m_ReportingEnabled) {
      v2i lns = instructionLines(a.instr, ictx);
      if (lns != v2i(-1)) {
        _lines.insert(lns);
      }
    }
    // write instruction
    {
      auto assign = dynamic_cast<siliceParser::AssignmentContext *>(a.instr);
      if (assign) {
        // retrieve var
        string var;
        if (assign->IDENTIFIER() != nullptr) {
          var = translateVIOName(assign->IDENTIFIER()->getText(), &block->context);
        } else {
          var = determineAccessedVar(assign->access(), &block->context);
        }
        // check if assigning to a wire
        if (m_VarNames.count(var) > 0) {
          if (m_Vars.at(m_VarNames.at(var)).usage == e_Wire) {
            reportError(sourceloc(assign), "cannot assign a variable bound to an expression");
          }
        }
        // write
        writeAssignement(prefix, out, a, assign->access(), assign->IDENTIFIER(), assign->expression_0(), &block->context, ictx, FF_Q, _dependencies, _ff_usage);
      }
    } {
      auto alw = dynamic_cast<siliceParser::AlwaysAssignedContext *>(a.instr);
      if (alw) {
          // check if this always assignment is on a wire var, if yes, skip it
          bool skip = false;
          // -> determine assigned var
          string var;
          if (alw->IDENTIFIER() != nullptr) {
            var = translateVIOName(alw->IDENTIFIER()->getText(), &block->context);
          } else {
            var = determineAccessedVar(alw->access(), &block->context);
          }
          if (m_VarNames.count(var) > 0) {
            skip = (m_Vars.at(m_VarNames.at(var)).usage == e_Wire);
          }
          if (!skip) {
            if (alw->ALWSASSIGNDBL() != nullptr) {
              std::ostringstream ostr;
              writeAssignement(prefix, ostr, a, alw->access(), alw->IDENTIFIER(), alw->expression_0(), &block->context, ictx, FF_Q, _dependencies, _ff_usage);
              // modify assignement to insert temporary var
              std::size_t pos = ostr.str().find('=');
              std::string lvalue = ostr.str().substr(0, pos - 1);
              std::string rvalue = ostr.str().substr(pos + 1);
              std::string tmpvar = "_delayed_" + std::to_string(alw->getStart()->getLine()) + "_" + std::to_string(alw->getStart()->getCharPositionInLine());
              out << lvalue << " = " << FF_D << tmpvar << ';' << nxl;
              out << FF_D << tmpvar << " = " << rvalue; // rvalue includes the line end ";\n"
            } else {
              writeAssignement(prefix, out, a, alw->access(), alw->IDENTIFIER(), alw->expression_0(), &block->context, ictx, FF_Q, _dependencies, _ff_usage);
            }
          }
      }
    } {
      auto assert = dynamic_cast<siliceParser::Assert_Context *>(a.instr);
      if (assert) {
        writeAssert(prefix, out, a, assert->expression_0(), &block->context, ictx, FF_Q, _dependencies, _ff_usage);
      }
    } {
      auto assume = dynamic_cast<siliceParser::AssumeContext *>(a.instr);
      if (assume) {
        writeAssume(prefix, out, a, assume->expression_0(), &block->context, ictx, FF_Q, _dependencies, _ff_usage);
      }
    } {
      auto restrict = dynamic_cast<siliceParser::RestrictContext *>(a.instr);
      if (restrict) {
        writeRestrict(prefix, out, a, restrict->expression_0(), &block->context, ictx, FF_Q, _dependencies, _ff_usage);
      }
    } {
      auto cover = dynamic_cast<siliceParser::CoverContext *>(a.instr);
      if (cover) {
        writeCover(prefix, out, a, cover->expression_0(), &block->context, ictx, FF_Q, _dependencies, _ff_usage);
      }
    } {
      auto display = dynamic_cast<siliceParser::DisplayContext *>(a.instr);
      if (display) {
        if (display->DISPLAY() != nullptr) {
          out << "$display(";
        } else if (display->DISPLWRITE() != nullptr) {
          out << "$write(";
        }
        out << display->STRING()->getText();
        if (display->callParamList() != nullptr) {
          std::vector<t_call_param> params;
          getCallParams(display->callParamList(),params, &block->context);
          for (auto p : params) {
            if (std::holds_alternative<std::string>(p.what)) {
              out << "," << rewriteIdentifier(prefix, std::get<std::string>(p.what), "", &block->context, ictx, sourceloc(display), FF_Q, true, _dependencies, _ff_usage);
            } else {
              out << "," << rewriteExpression(prefix, p.expression, a.__id, &block->context, ictx, FF_Q, true, _dependencies, _ff_usage);
            }
          }
        }
        out << ");" << nxl;
      }
    } {
      auto inline_v = dynamic_cast<siliceParser::Inline_vContext *>(a.instr);
      if (inline_v) {
        // get raw string
        auto raw = inline_v->STRING()->getText();
        raw      = raw.substr(1, raw.length() - 2);
        raw.erase(std::remove(raw.begin(), raw.end(), '\\'), raw.end()); // this is getting rid of escape sequences
        // split it wrt to '%'
        vector<string> chunks;
        split(raw, '%', chunks);
        // get params
        std::vector<t_call_param> params;
        getCallParams(inline_v->callParamList(), params, &block->context);
        // output
        int ip = 0;
        for (auto c : chunks) {
          out << c;
          if (ip < params.size()) {
            auto p = params[ip];
            if (std::holds_alternative<std::string>(p.what)) {
              out << rewriteIdentifier(prefix, std::get<std::string>(p.what), "", &block->context, ictx, sourceloc(inline_v), FF_Q, true, _dependencies, _ff_usage);
            } else {
              out << rewriteExpression(prefix, p.expression, a.__id, &block->context, ictx, FF_Q, true, _dependencies, _ff_usage);
            }
            ++ip;
          } else if (ip > params.size()) {
            reportError(sourceloc(inline_v),"no enough parameters given compared to the number of '%%' in the string");
          }
        }
      }
      out << nxl;
    } {
      auto finish = dynamic_cast<siliceParser::FinishContext *>(a.instr);
      if (finish) {
        out << "$finish();" << nxl;
      }
    } {
      auto async = dynamic_cast<siliceParser::AsyncExecContext *>(a.instr);
      if (async) {
        // find algorithm
        auto A = m_InstancedBlueprints.find(async->IDENTIFIER()->getText());
        if (A == m_InstancedBlueprints.end()) {
          // check if this is an erronous call to a subroutine
          auto S = m_Subroutines.find(async->IDENTIFIER()->getText());
          if (S == m_Subroutines.end()) {
            reportError(sourceloc(async),
              "cannot find algorithm '%s' on asynchronous call",
              async->IDENTIFIER()->getText().c_str());
          } else {
            reportError(sourceloc(async),
              "cannot perform an asynchronous call on subroutine '%s'",
              async->IDENTIFIER()->getText().c_str());
          }
        } else {
          writeAlgorithmCall(a.instr, prefix, out, A->second, async->callParamList(), &block->context, ictx, _dependencies, _ff_usage);
        }
      }
    } {
      auto sync = dynamic_cast<siliceParser::SyncExecContext *>(a.instr);
      if (sync) {
        // find algorithm
        auto A = m_InstancedBlueprints.find(sync->joinExec()->IDENTIFIER()->getText());
        if (A == m_InstancedBlueprints.end()) {
          // call to a subroutine?
          auto S = m_Subroutines.find(sync->joinExec()->IDENTIFIER()->getText());
          if (S == m_Subroutines.end()) {
            reportError(sourceloc(sync),
              "cannot find algorithm '%s' on synchronous call",
              sync->joinExec()->IDENTIFIER()->getText().c_str());
          } else {
            writeSubroutineCall(a.instr, prefix, out, S->second, &block->context, ictx, sync->callParamList(), _dependencies, _ff_usage);
          }
        } else {
          writeAlgorithmCall(a.instr, prefix, out, A->second, sync->callParamList(), &block->context, ictx, _dependencies, _ff_usage);
        }
      }
    } {
      auto join = dynamic_cast<siliceParser::JoinExecContext *>(a.instr);
      if (join) {
        // find algorithm
        auto A = m_InstancedBlueprints.find(join->IDENTIFIER()->getText());
        if (A == m_InstancedBlueprints.end()) {
          // return of subroutine?
          auto S = m_Subroutines.find(join->IDENTIFIER()->getText());
          if (S == m_Subroutines.end()) {
            reportError(sourceloc(join),
              "cannot find algorithm '%s' to join with",
              join->IDENTIFIER()->getText().c_str(), (int)join->getStart()->getLine());
          } else {
            writeSubroutineReadback(a.instr, prefix, out, S->second, &block->context, ictx, join->callParamList(), _ff_usage);
          }
        } else {
          writeAlgorithmReadback(a.instr, prefix, out, A->second, join->callParamList(), &block->context, ictx, _ff_usage);
        }
      }
    } {
      auto ret = dynamic_cast<siliceParser::ReturnFromContext *>(a.instr);
      if (ret) {
        if (hasNoFSM()) {
          reportError(sourceloc(ret), "cannot return from a stateless algorithm");
        }

        out << FF_D << prefix << ALG_IDX << " = " << toFSMState(terminationState()) << ";" << nxl;
      }
    }
    // update dependencies
    updateAndCheckDependencies(_dependencies, a.instr, &block->context);
  }
}

// -------------------------------------------------

void Algorithm::writeStatelessBlockGraph(
  std::string prefix, std::ostream& out,
  const t_instantiation_context &ictx,
  const t_combinational_block* block,
  const t_combinational_block* stop_at,
  std::queue<size_t>& _q,
  t_vio_dependencies& _dependencies,
  t_vio_ff_usage&     _ff_usage,
  t_vio_dependencies& _post_dependencies,
  std::set<v2i> &_lines) const
{
  // recursive call?
  if (stop_at != nullptr) {
    sl_assert(!(block->is_state && block->is_sub_state));
    // if called on a state, index state and stop there
    if (block->is_state) {
      // yes: index the state directly
      out << FF_D << prefix << ALG_IDX " = " << toFSMState(fastForward(block)->state_id) << ";" << nxl;
      pushState(block, _q);
      mergeDependenciesInto(_dependencies, _post_dependencies);
      return;
    }
    // if called on a sub-state, do nothing but stop here
    if (block->is_sub_state) {
      mergeDependenciesInto(_dependencies, _post_dependencies);
      return;
    }
  }
  // follow the chain
  const t_combinational_block *current = block;
  while (true) {
    // write current block
    writeBlock(prefix, out, ictx, current, _dependencies, _ff_usage, _lines);
    // merge
    // goto next in chain
    if (current->next()) {
      current = current->next()->next;
    } else if (current->if_then_else()) {
      vector<t_vio_ff_usage> usage_branches;
      out << "if (" << rewriteExpression(prefix, current->if_then_else()->test.instr, current->if_then_else()->test.__id, &current->context, ictx, FF_Q, true, _dependencies, _ff_usage) << ") begin" << nxl;
      // add to lines
      if (m_ReportingEnabled) {
        v2i lns = instructionLines(current->if_then_else()->test.instr, ictx);
        if (lns != v2i(-1)) {
          _lines.insert(lns);
        }
      }
      // recurse if
      t_vio_dependencies depds_if = _dependencies;
      usage_branches.push_back(_ff_usage/*t_vio_ff_usage()*/);
      writeStatelessBlockGraph(prefix, out, ictx, current->if_then_else()->if_next, current->if_then_else()->after, _q, depds_if, usage_branches.back(), _post_dependencies, _lines);
      out << "end else begin" << nxl;
      // recurse else
      t_vio_dependencies depds_else = _dependencies;
      usage_branches.push_back(_ff_usage/*t_vio_ff_usage()*/);
      writeStatelessBlockGraph(prefix, out, ictx, current->if_then_else()->else_next, current->if_then_else()->after, _q, depds_else, usage_branches.back(), _post_dependencies, _lines);
      out << "end" << nxl;
      // merge dependencies
      mergeDependenciesInto(depds_if, _dependencies);
      mergeDependenciesInto(depds_else, _dependencies);
      // combine ff usage
      combineFFUsageInto(current,_ff_usage, usage_branches, _ff_usage);
      // follow after?
      if (current->if_then_else()->after->is_state) {
        mergeDependenciesInto(_dependencies, _post_dependencies);
        return; // no: already indexed by recursive calls
      } else {
        current = current->if_then_else()->after; // yes!
      }
    } else if (current->switch_case()) {
      if (current->switch_case()->onehot) {
        out << "(* parallel_case, full_case *)" << nxl;
        out << "  case (1'b1)" << nxl;
      } else {
        out << "  case (" << rewriteExpression(prefix, current->switch_case()->test.instr, current->switch_case()->test.__id, &current->context, ictx, FF_Q, true, _dependencies, _ff_usage) << ")" << nxl;
      }
      std::string identifier;
      if (current->switch_case()->onehot) {
        bool isidentifier = isIdentifier(current->switch_case()->test.instr, identifier);
        if (!isidentifier) { throw Fatal("internal error (onehot switch)"); }
      }
      // add to lines
      if (m_ReportingEnabled) {
        v2i lns = instructionLines(current->switch_case()->test.instr, ictx);
        if (lns != v2i(-1)) {
          _lines.insert(lns);
        }
      }
      // recurse block
      t_vio_dependencies depds_before_case = _dependencies;
      vector<t_vio_ff_usage> usage_branches;
      bool has_default = false;
      for (auto cb : current->switch_case()->case_blocks) {
        if (current->switch_case()->onehot && cb.first != "default") {
          out << "  "
            << rewriteIdentifier(prefix, identifier, "", &current->context, ictx, cb.second->srcloc, FF_Q, true, _dependencies, _ff_usage)
            << "[" << cb.first << "]: begin" << nxl;
          /// TODO: if cb.first is const, check it is below identifier bit width
        } else {
          out << "  " << cb.first << ": begin" << nxl;
        }
        has_default = has_default | (cb.first == "default");
        // recurse case
        t_vio_dependencies depds_case = depds_before_case;
        usage_branches.push_back(_ff_usage/*t_vio_ff_usage()*/);
        writeStatelessBlockGraph(prefix, out, ictx, cb.second, current->switch_case()->after, _q, depds_case, usage_branches.back(), _post_dependencies, _lines);
        // merge sets of written vars
        mergeDependenciesInto(depds_case, _dependencies);
        out << "  end" << nxl;
      }
      // end of case
      out << "endcase" << nxl;
      // checks
      if (current->switch_case()->onehot) {
        if (!has_default) {
          string var = translateVIOName(identifier, &current->context);
          bool found = false;
          auto def = getVIODefinition(var, found);
          if (found) {
            string wdth = varBitWidth(def, ictx);
            if (!is_number(wdth)) {
              reportError(def.srcloc, "cannot find width of '%s' during instantiation of unit '%s'", def.name.c_str(), m_Name.c_str());
            }
            int width = atoi(wdth.c_str());
            if (current->switch_case()->case_blocks.size() != width) {
              reportError(current->srcloc, "onehot switch case without default does not have the correct number of entries\n     (%s is %d bits wide, expecting %d entries, found %d)", var.c_str(), width, width, current->switch_case()->case_blocks.size());
            }
          }
        }
      }
      // merge ff usage
      if (!has_default && !current->switch_case()->onehot) {
        usage_branches.push_back(_ff_usage/*t_vio_ff_usage()*/); // push an empty set
        // NOTE: the case could be complete, currently not checked ; safe but missing an opportunity
      }
      combineFFUsageInto(current,_ff_usage, usage_branches, _ff_usage);
      // follow after?
      if (current->switch_case()->after->is_state) {
        mergeDependenciesInto(_dependencies, _post_dependencies);
        return; // no: already indexed by recursive calls
      } else {
        current = current->switch_case()->after; // yes!
      }
    } else if (current->while_loop()) {
      // while
      out << "if (" << rewriteExpression(prefix, current->while_loop()->test.instr, current->while_loop()->test.__id, &current->context, ictx, FF_Q, true, _dependencies, _ff_usage) << ") begin" << nxl;
      writeStatelessBlockGraph(prefix, out, ictx, current->while_loop()->iteration, current->while_loop()->after, _q, _dependencies, _ff_usage, _post_dependencies, _lines);
      out << "end else begin" << nxl;
      out << FF_D << prefix << ALG_IDX " = " << toFSMState(fastForward(current->while_loop()->after)->state_id) << ";" << nxl;
      pushState(current->while_loop()->after, _q);
      out << "end" << nxl;
      mergeDependenciesInto(_dependencies, _post_dependencies);
      // add to lines
      if (m_ReportingEnabled) {
        v2i lns = instructionLines(current->while_loop()->test.instr, ictx);
        if (lns != v2i(-1)) {
          _lines.insert(lns);
        }
      }
      return;
    } else if (current->return_from()) {
      // return to caller (goes to termination of algorithm is not set)
      sl_assert(current->context.subroutine != nullptr);
      auto RS = m_SubroutinesCallerReturnStates.find(current->context.subroutine->name);
      if (RS != m_SubroutinesCallerReturnStates.end()) {
        if (RS->second.size() > 1) {
          out << "case (" << FF_Q << prefix << ALG_CALLER << ") " << nxl;
          for (auto caller_return : RS->second) {
            out << width(m_SubroutineCallerNextId) << "'d" << caller_return.first << ": begin" << nxl;
            out << "  " << FF_D << prefix << ALG_IDX " = " << stateWidth() << "'d" << toFSMState(fastForward(caller_return.second)->state_id) << ';' << nxl;
            // if returning to a subroutine, restore caller id
            if (caller_return.second->context.subroutine != nullptr) {
              sl_assert(caller_return.second->context.subroutine->contains_calls);
              out << "  " << FF_D << prefix << ALG_CALLER << " = " << FF_Q << prefix << caller_return.second->context.subroutine->name << '_' << ALG_CALLER << ';' << nxl;
            }
            out << "end" << nxl;
          }
          out << "default: begin " << FF_D << prefix << ALG_IDX " = " << stateWidth() << "'d" << terminationState() << "; end" << nxl;
          out << "endcase" << nxl;
        } else {
          auto caller_return = *RS->second.begin();
          out << FF_D << prefix << ALG_IDX " = " << stateWidth() << "'d" << toFSMState(fastForward(caller_return.second)->state_id) << ';' << nxl;
          // if returning to a subroutine, restore caller id
          if (caller_return.second->context.subroutine != nullptr) {
            sl_assert(caller_return.second->context.subroutine->contains_calls);
            out << FF_D << prefix << ALG_CALLER << " = " << FF_Q << prefix << caller_return.second->context.subroutine->name << '_' << ALG_CALLER << ';' << nxl;
          }
        }
      } else {
        // this subroutine is never called??
        out << FF_D << prefix << ALG_IDX " = " << stateWidth() << "'d" << terminationState() << ';' << nxl;
      }
      mergeDependenciesInto(_dependencies, _post_dependencies);
      return;
    } else if (current->goto_and_return_to()) {
      // goto subroutine
      out << FF_D << prefix << ALG_IDX " = " << toFSMState(fastForward(current->goto_and_return_to()->go_to)->state_id) << ";" << nxl;
      pushState(current->goto_and_return_to()->go_to, _q);
      // if in subroutine making nested calls, store callerid
      if (current->context.subroutine != nullptr) {
        sl_assert(current->context.subroutine->contains_calls);
        out << FF_D << prefix << current->context.subroutine->name << '_' << ALG_CALLER << " = " << FF_Q << prefix << ALG_CALLER << ";" << nxl;
      }
      // set caller id
      auto C = m_SubroutineCallerIds.find(current->goto_and_return_to());
      sl_assert(C != m_SubroutineCallerIds.end());
      out << FF_D << prefix << ALG_CALLER << " = " << C->second << ";" << nxl;
      pushState(current->goto_and_return_to()->return_to, _q);
      mergeDependenciesInto(_dependencies, _post_dependencies);
      return;
    } else if (current->wait()) {
      // wait for algorithm
      auto A = m_InstancedBlueprints.find(current->wait()->algo_instance_name);
      if (A == m_InstancedBlueprints.end()) {
        reportError(current->wait()->srcloc,
        "cannot find algorithm '%s' to join with",
          current->wait()->algo_instance_name.c_str());
      } else {
        // test if algorithm is done
        out << "if (" WIRE << A->second.instance_prefix + "_" + ALG_DONE " == 1) begin" << nxl;
        // yes!
        // -> goto next
        out << FF_D << prefix << ALG_IDX " = " << toFSMState(fastForward(current->wait()->next)->state_id) << ";" << nxl;
        pushState(current->wait()->next, _q);
        out << "end else begin" << nxl;
        // no!
        // -> wait
        out << FF_D << prefix << ALG_IDX " = " << toFSMState(fastForward(current->wait()->waiting)->state_id) << ";" << nxl;
        pushState(current->wait()->waiting, _q);
        out << "end" << nxl;
      }
      mergeDependenciesInto(_dependencies, _post_dependencies);
      return;
    } else if (current->pipeline_next()) {
      // write pipeline
      current = writeStatelessPipeline(prefix, out, ictx, current, _q, _dependencies, _ff_usage, _post_dependencies, _lines);
    } else {
      // necessary as m_AlwaysPre/m_AlwaysPost reaches this
      if (block != &m_AlwaysPre && block != &m_AlwaysPost) {
        if (!hasNoFSM()) {
          // no action, goto end
          out << FF_D << prefix << ALG_IDX " = " << toFSMState(terminationState()) << ";" << nxl;
        }
      }
      mergeDependenciesInto(_dependencies, _post_dependencies);
      return;
    }
    // check whether next is a state
    if (current->is_state) {
      // yes: index and stop
      out << FF_D << prefix << ALG_IDX " = " << toFSMState(fastForward(current)->state_id) << ";" << nxl;
      pushState(current, _q);
      mergeDependenciesInto(_dependencies, _post_dependencies);
      return;
    }
    // check whether next is a sub-state
    if (current->is_sub_state) {
      mergeDependenciesInto(_dependencies, _post_dependencies);
      return;
    }
    // reached stop?
    if (current == stop_at) {
      mergeDependenciesInto(_dependencies, _post_dependencies);
      return;
    }
    // keep going
  }
  mergeDependenciesInto(_dependencies, _post_dependencies);
}

// -------------------------------------------------

const Algorithm::t_combinational_block *Algorithm::writeStatelessPipeline(
  std::string prefix, std::ostream& out, const t_instantiation_context &ictx,
  const t_combinational_block* block_before,
  std::queue<size_t>& _q,
  t_vio_dependencies& _dependencies,
  t_vio_ff_usage&     _ff_usage,
  t_vio_dependencies& _post_dependencies,
  std::set<v2i>&      _lines) const
{
  // follow the chain
  out << "// pipeline" << nxl;
  const t_combinational_block *current   = block_before->pipeline_next()->next;
  const t_combinational_block *after     = block_before->pipeline_next()->after;
  const t_pipeline_nfo        *pip       = current->context.pipeline->pipeline;
  sl_assert(pip != nullptr);
  t_vio_dependencies depds_before_stages = _dependencies;

  // first, gather stages
  const t_combinational_block *cur = current;
  const t_combinational_block *aft = after;
  typedef struct {
    const t_combinational_block *current;
    const t_combinational_block *after;
  } t_stage;
  std::vector< t_stage > stages;
  while (true) {
    sl_assert(pip == cur->context.pipeline->pipeline);
    stages.push_back({ cur,aft });
    if (cur != aft) {
      cur = aft;
    }
    if (cur->pipeline_next()) {
      aft = cur->pipeline_next()->after;
      cur = cur->pipeline_next()->next;
    } else {
      break; // done
    }
  }

  // reverse stages
  std::reverse(stages.begin(), stages.end());

  for (auto st : stages) {
    sl_assert(pip == st.current->context.pipeline->pipeline);
    // write stage
    int stage = st.current->context.pipeline->stage_id;
    out << "// -------- stage " << stage << nxl;
    t_vio_dependencies deps = depds_before_stages;
    // write code
    if (st.current != st.after) { // this is the more complex case of multiple blocks in stage
      writeStatelessBlockGraph(prefix, out, ictx, st.current, st.after, _q, deps, _ff_usage, _post_dependencies, _lines); // NOTE: q will not be changed since this is a combinational block
      st.current = st.after;
    } else {
      writeBlock(prefix, out, ictx, st.current, deps, _ff_usage, _lines);
    }
    clearNoLatchFFUsage(_ff_usage);
    // for vios written before, retain dependencies
    for (const auto& d : deps.dependencies) {
      if (st.current->context.pipeline->written_before.count(d.first)) {
        depds_before_stages.dependencies[d.first].insert(d.second.begin(),d.second.end());
      }
    }
    // trickle vars: start
    for (auto tv : pip->trickling_vios) {
      if (stage == tv.second[0]) {
        // capture the var in the pipeline
        std::string tricklingdst = tricklingVIOName(tv.first, pip, stage);
        out << rewriteIdentifier(prefix, tricklingdst, "", &st.current->context, ictx, t_source_loc(), FF_D, true, deps, _ff_usage) << " = ";
        out << rewriteIdentifier(prefix, tv.first, "", &st.current->context, ictx, t_source_loc(), FF_D, true, deps, _ff_usage);
        out << ';' << nxl;
      } else if (stage < tv.second[1]) {
        // mark var ff as needed (Q side) for next stages
        std::string trickling = translateVIOName(tv.first, &st.current->context);
        updateFFUsage(e_Q, true, _ff_usage.ff_usage[trickling]);
      }
    }
    // merge dependencies
    mergeDependenciesInto(deps, _dependencies);
  }
  // done (using front since stages are reverted
  if (!stages.front().after->pipeline_next()) {
    sl_assert(stages.front().after->next() != nullptr);
    return stages.front().after->next()->next;
  }
  sl_assert(false);
  return nullptr;
}

// -------------------------------------------------

void Algorithm::writeVarInits(std::string prefix, std::ostream& out, const t_instantiation_context &ictx, const std::unordered_map<std::string, int >& varnames, t_vio_dependencies& _dependencies, t_vio_ff_usage &_ff_usage) const
{
  // visit vars in order of declaration
  vector<int> indices;
  for (const auto& vn : varnames) {
    indices.push_back(vn.second);
  }
  sort(indices.begin(), indices.end());
  for (auto idx : indices) {
    const auto& v = m_Vars.at(idx);
    if (v.usage  != e_FlipFlop && v.usage != e_Temporary)  continue;
    if (v.access == e_WriteOnly) continue;
    if (v.do_not_initialize)     continue;
    if (v.init_at_startup)       continue;
    string ff = (v.usage == e_FlipFlop) ? FF_D : FF_TMP;
    if (v.table_size == 0) {
      out << ff << prefix << v.name << " = " << varInitValue(v, ictx) << ';' << nxl;
    } else {
      sl_assert(v.type_nfo.base_type != Parameterized);
      ForIndex(i, v.init_values.size()) {
        out << ff << prefix << v.name << "[" << i << ']' << " = " << v.init_values[i] << ';' << nxl;
      }
    }
    // insert write in dependencies
    _dependencies.dependencies.insert(std::make_pair(v.name, 0));
  }
}

// -------------------------------------------------

std::string Algorithm::memoryModuleName(std::string instance_name, const t_mem_nfo &bram) const
{
  return "M_" + m_Name + "_" + instance_name + "_mem_" + bram.name;
}

// -------------------------------------------------

void Algorithm::prepareModuleMemoryTemplateReplacements(std::string instance_name, const t_mem_nfo& bram, std::unordered_map<std::string, std::string>& _replacements) const
{
  string memid;
  std::vector<t_mem_member> members;
  switch (bram.mem_type) {
  case BRAM:           members = c_BRAMmembers; memid = "bram";  break;
  case BROM:           members = c_BROMmembers; memid = "brom"; break;
  case DUALBRAM:       members = c_DualPortBRAMmembers; memid = "dualport_bram"; break;
  case SIMPLEDUALBRAM: members = c_SimpleDualPortBRAMmembers; memid = "simple_dualport_bram";  break;
  default: reportError(t_source_loc(), "internal error (memory type)"); break;
  }
  _replacements["MODULE"] = memoryModuleName(instance_name,bram);
  for (const auto& m : members) {
    string nameup = m.name;
    std::transform(nameup.begin(), nameup.end(), nameup.begin(),
      [](unsigned char c) { return std::toupper(c); }
    );
    if (m.is_addr) {
      _replacements[nameup + "_WIDTH"] = std::to_string(justHigherPow2(bram.table_size));
    } else {
      // search config
      string width = "";
      auto C = CONFIG.keyValues().find(bram.custom_template + "_" + m.name + "_width");
      if (C == CONFIG.keyValues().end() || bram.custom_template.empty()) {
        C = CONFIG.keyValues().find(memid + "_" + m.name + "_width");
      }
      if (C == CONFIG.keyValues().end()) {
        width = std::to_string(bram.type_nfo.width);
      } else if (C->second == "1") {
        width = "1";
      } else if (C->second == "data") {
        width = std::to_string(bram.type_nfo.width);
      }
      _replacements[nameup + "_WIDTH"] = width;
      // search config
      string sgnd = "";
      auto T = CONFIG.keyValues().find(bram.custom_template + "_" + m.name + "_type");
      if (T == CONFIG.keyValues().end() || bram.custom_template.empty()) {
        T = CONFIG.keyValues().find(memid + "_" + m.name + "_type");
      }
      if (T == CONFIG.keyValues().end()) {
        sgnd = typeString(bram.type_nfo.base_type);
      } else if (T->second == "uint") {
        sgnd = "";
      } else if (T->second == "int") {
        sgnd = "signed";
      } else if (T->second == "data") {
        sgnd = typeString(bram.type_nfo.base_type);
      }
      _replacements[nameup + "_TYPE"] = sgnd;
    }
  }
  _replacements["DATA_TYPE"] = typeString(bram.type_nfo.base_type);
  _replacements["DATA_WIDTH"] = std::to_string(bram.type_nfo.width);
  _replacements["DATA_SIZE"] = std::to_string(bram.table_size);
  ostringstream initial;
  if (!bram.do_not_initialize) {
    initial << "initial begin" << nxl;
    ForIndex(v, bram.init_values.size()) {
      initial << " buffer[" << v << "] = " << bram.init_values[v] << ';' << nxl;
    }
    initial << "end" << nxl;
  }
  _replacements["INITIAL"] = initial.str();
}

// -------------------------------------------------

void Algorithm::writeModuleMemory(std::string instance_name, std::ostream& out, const t_mem_nfo& mem) const
{
  // prepare replacement vars
  std::unordered_map<std::string, std::string> replacements;
  prepareModuleMemoryTemplateReplacements(instance_name, mem, replacements);
  // base template name
  string base;
  switch (mem.mem_type) {
  case BRAM:           base = "bram_template"; break;
  case BROM:           base = "brom_template"; break;
  case DUALBRAM:       base = "dualport_bram_template"; break;
  case SIMPLEDUALBRAM: base = "simple_dualport_bram_template"; break;
  default: throw Fatal("internal error (unknown memory type)"); break;
  }
  // load template
  VerilogTemplate tmplt;
  tmplt.load(CONFIG.keyValues()["templates_path"] + "/" +
    (mem.custom_template.empty() ? CONFIG.keyValues()[base] : (mem.custom_template + ".v.in")),
    replacements);
  // write to output
  out << tmplt.code();
  out << nxl;
}

// -------------------------------------------------

void Algorithm::setAsTopMost()
{
  m_TopMost = true; // this is the topmost
  if (!m_ReportBaseName.empty() && !m_hasHash) {
    // create report files, will delete if existing
    std::ofstream freport_a(algReportName());
    std::ofstream freport_v(vioReportName());
    std::ofstream freport_f(fsmReportName());
  }
}

// -------------------------------------------------

void Algorithm::writeAsModule(SiliceCompiler *compiler, std::ostream &out, const t_instantiation_context &ictx, bool first_pass)
{
  // instantiate all blueprints
  instantiateBlueprints(compiler, out, ictx, first_pass);

  if (first_pass) {

    /// first pass

    // optimize
    optimize(ictx);
    // lint upon instantiation
    lint(ictx);

    // activate reporting?
    m_ReportingEnabled = (!m_ReportBaseName.empty());
    if (m_ReportingEnabled) {
      // algorithm report
      std::ofstream freport(algReportName(), std::ios_base::app);
      sl_assert(!m_Blocks.empty());
      auto tk = getToken(m_Blocks.front()->srcloc.root, m_Blocks.front()->srcloc.interval);
      if (tk) {
        std::pair<std::string, int> fl = getTokenSourceFileAndLine(m_Blocks.front()->srcloc.root, tk);
        freport
          << (ictx.instance_name.empty()       ? "__main" : ictx.instance_name) << " "
          << (ictx.local_instance_name.empty() ? "main"   : ictx.local_instance_name) << " "
          << m_Name << " " << fl.first << " "
          << (m_FormalDepth.empty()   ? "30"  : m_FormalDepth) << " "
          << (m_FormalTimeout.empty() ? "120" : m_FormalTimeout) << " ";
        auto end = m_FormalModes.size();
        for (size_t i{0}; i < end - 1; ++i) {
          freport << m_FormalModes[i] << ",";
        }
        freport << m_FormalModes[end - 1] << nxl;
      }
    }

    // first pass, discarded but used to fine tune detection of temporary VIOs
    {
      t_vio_ff_usage ff_usage;
      std::ofstream null;
      writeAsModule(compiler, null, ictx, ff_usage, first_pass);

      // update usage based on first pass
      for (const auto &v : ff_usage.ff_usage) {
        if (!(v.second & e_Q)) { // Q side is never used
          if (m_VarNames.count(v.first)) { // variable?
            if (m_Vars.at(m_VarNames.at(v.first)).usage == e_FlipFlop) {
              if (m_Vars.at(m_VarNames.at(v.first)).access == e_ReadOnly) {
                m_Vars.at(m_VarNames.at(v.first)).usage = e_Const;
              } else {
                if (m_Vars.at(m_VarNames.at(v.first)).table_size == 0) { // if not a table (all entries have to be latched)
                  m_Vars.at(m_VarNames.at(v.first)).usage = e_Temporary;
                }
              }
            }
          }
          if (hasNoFSM()) {
            // if there is no FSM, the algorithm is combinational and this output does not need to be registered
            if (m_OutputNames.count(v.first)) {
              if (m_Outputs.at(m_OutputNames.at(v.first)).usage == e_FlipFlop) {
                m_Outputs.at(m_OutputNames.at(v.first)).usage = e_Temporary;
              }
            }
          } else {
            // check if combinational output can be turned into a temporary
            if (m_OutputNames.count(v.first)) {
              if ( m_Outputs.at(m_OutputNames.at(v.first)).usage == e_FlipFlop
                && m_Outputs.at(m_OutputNames.at(v.first)).combinational) {
                m_Outputs.at(m_OutputNames.at(v.first)).usage = e_Temporary;
              }
            }
          }
        }
      }

#if 0
      std::cerr << " === algorithm " << m_Name << " ====" << nxl;
      for (const auto &v : ff_usage.ff_usage) {
        std::cerr << "vio " << v.first << " : ";
        if (v.second & e_D) {
          std::cerr << "D";
        }
        if (v.second & e_Q) {
          std::cerr << "Q";
        }
        std::cerr << nxl;
      }
#endif

    }

  } else {

    /// second pass, now that VIO usage is refined

    // turn reporting off in second pass
    m_ReportingEnabled = false;

    t_vio_ff_usage ff_usage;
    writeAsModule(compiler, out, ictx, ff_usage, first_pass);

    // output VIO report (if enabled)
    if (!m_ReportBaseName.empty()) {
      outputVIOReport(ictx);
    }

  }

}

// -------------------------------------------------

const Algorithm::t_binding_nfo &Algorithm::findBindingLeft(std::string left, const std::vector<t_binding_nfo> &bndgs, bool& _found) const
{
  _found = false;
  for (const auto &b : bndgs) {
    if (b.left == left) {
      _found = true;
      return b;
    }
  }
  static t_binding_nfo foo;
  return foo;
}

// -------------------------------------------------

const Algorithm::t_binding_nfo &Algorithm::findBindingRight(std::string right, const std::vector<t_binding_nfo> &bndgs, bool& _found) const
{
  _found = false;
  for (const auto &b : bndgs) {
    if (bindingRightIdentifier(b) == right) {
      _found = true;
      return b;
    }
  }
  static t_binding_nfo foo;
  return foo;
}

// -------------------------------------------------

bool Algorithm::getVIONfo(std::string vio, t_var_nfo& _nfo) const
{
  bool found = false;
  _nfo = getVIODefinition(vio,found);
  return found;
}

// -------------------------------------------------

bool Algorithm::varIsInInstantiationContext(std::string var, const t_instantiation_context& ictx) const
{
  // resolve parameter value
  std::transform(var.begin(), var.end(), var.begin(),
    [](unsigned char c) -> unsigned char { return std::toupper(c); });
  string str_width = var + "_WIDTH";
  string str_init = var + "_INIT";
  string str_signed = var + "_SIGNED";
  return ( ictx.parameters.count(str_width)  != 0
        && ictx.parameters.count(str_init)   != 0
        && ictx.parameters.count(str_signed) != 0 );
}

// -------------------------------------------------

void Algorithm::addToInstantiationContext(const Algorithm *alg, std::string var, const t_var_nfo& bnfo, const t_instantiation_context& ictx, t_instantiation_context& _local_ictx) const
{
  // resolve parameter value
  std::transform(var.begin(), var.end(), var.begin(),
    [](unsigned char c) -> unsigned char { return std::toupper(c); });
  string str_width  = var  + "_WIDTH";
  string str_init   = var   + "_INIT";
  string str_signed = var + "_SIGNED";
  _local_ictx.parameters[str_width]  = alg->varBitWidth(bnfo, ictx);
  _local_ictx.parameters[str_init]   = alg->varInitValue(bnfo, ictx);
  _local_ictx.parameters[str_signed] = typeString(alg->varType(bnfo, ictx));
}

// -------------------------------------------------

void Algorithm::makeBlueprintInstantiationContext(const t_instanced_nfo& nfo, const t_instantiation_context& ictx, t_instantiation_context& _local_ictx) const
{
  _local_ictx = ictx;
  // parameters for parameterized variables
  ForIndex(i, nfo.blueprint->parameterized().size()) {
    string var = nfo.blueprint->parameterized()[i];
    if (varIsInInstantiationContext(var, nfo.specializations)) {
      // var has been specialized explicitly already
      continue;
    }
    bool found = false;
    auto io_nfo = nfo.blueprint->getVIODefinition(var, found);
    sl_assert(found);
    if (io_nfo.type_nfo.same_as.empty()) {
      // a binding is needed to parameterize this io, find it
      found = false;
      const auto &b = findBindingLeft(var, nfo.bindings, found);
      if (!found) {
        reportError(nfo.srcloc, "io '%s' of instance '%s' is not bound nor specialized, cannot automatically determine it",
          var.c_str(), nfo.instance_name.c_str());
      }
      std::string bound = bindingRightIdentifier(b);
      t_var_nfo bnfo;
      if (!getVIONfo(bound, bnfo)) {
        continue; // NOTE: This is fine, we might be missing a binding that will be later resolved.
                  //       Later (when writing the output) this is strictly asserted.
                  //       This will only be an issue if the bound var is actually a paramterized var,
                  //       however the designer is expected to worry about instantiation order in such cases.
      }
      if (bnfo.table_size != 0) {
        // parameterized vars cannot be tables
        continue;
      }
      // add to context
      addToInstantiationContext(this, var, bnfo, _local_ictx, _local_ictx);
    }
  }
  // parameters of non-parameterized ios (for pre-processor widthof/signed)
  Algorithm *alg = dynamic_cast<Algorithm*>(nfo.blueprint.raw());
  for (auto io : nfo.blueprint->inputs()) {
    if (io.type_nfo.base_type != Parameterized || !io.type_nfo.same_as.empty()) {
      addToInstantiationContext(alg, io.name, io, _local_ictx, _local_ictx);
    }
  }
  for (auto io : nfo.blueprint->outputs()) {
    if (io.type_nfo.base_type != Parameterized || !io.type_nfo.same_as.empty()) {
      addToInstantiationContext(alg, io.name, io, _local_ictx, _local_ictx);
    }
  }
  for (auto io : nfo.blueprint->inOuts()) {
    if (io.type_nfo.base_type != Parameterized || !io.type_nfo.same_as.empty()) {
      addToInstantiationContext(alg, io.name, io, _local_ictx, _local_ictx);
    }
  }
  // instance context
  _local_ictx.instance_name = ictx.instance_name + "_" + nfo.instance_name;
  _local_ictx.local_instance_name = nfo.instance_name;
}

// -------------------------------------------------

void Algorithm::instantiateBlueprints(SiliceCompiler *compiler, ostream& out, const t_instantiation_context& ictx,bool first_pass)
{
  // write instantiated blueprints
  for (auto &iaiordr : m_InstancedBlueprintsInDeclOrder) {
    auto &nfo = m_InstancedBlueprints.at(iaiordr);
    if (first_pass) { /// first pass
      // generate or find blueprint
      sl_assert(nfo.blueprint.isNull());
      // check whether blueprint is static
      auto gbp = compiler->isStaticBlueprint(nfo.blueprint_name);
      if (!gbp.isNull()) {
        // this is a static blueprint, no instantiation needed
        nfo.blueprint = gbp;
      } else {
        cerr << "instantiating unit '" << nfo.blueprint_name << "' as '" << nfo.instance_name << "'\n";
        // parse the unit ios
        try {
          auto cbp = compiler->parseUnitIOs(nfo.blueprint_name);
          nfo.parsed_unit = cbp;
          nfo.blueprint   = cbp.unit;
        } catch (Fatal&) {
          reportError(nfo.srcloc, "could not instantiate unit '%s'", nfo.blueprint_name.c_str());
        }
      }
      // create vars for instanced blueprint inputs/outputs
      createInstancedBlueprintInputOutputVars(nfo);
      // resolve any automatic directional bindings
      resolveInstancedBlueprintBindingDirections(nfo);
      // perform autobind
      if (nfo.autobind) {
        autobindInstancedBlueprint(nfo);
      }
      // finish the unit if non static
      if (!nfo.parsed_unit.unit.isNull()) {
        // instantiation context
        t_instantiation_context local_ictx = ictx;
        local_ictx.parameters.insert(nfo.specializations.parameters.begin(), nfo.specializations.parameters.end());
        // update the instantiation context now that we have the unit ios
        makeBlueprintInstantiationContext(nfo, local_ictx, local_ictx);
        // record the specializations
        nfo.specializations = local_ictx;
        // resolve instanced blueprint inputs/outputs var types
        resolveInstancedBlueprintInputOutputVarTypes(nfo, local_ictx);
        // parse the unit body
        compiler->parseUnitBody(nfo.parsed_unit, local_ictx);
        // write the unit, first pass
        compiler->writeUnit(nfo.parsed_unit, local_ictx, out, first_pass);
      }
    } else { /// second pass
      sl_assert(!nfo.blueprint.isNull());
      if (!nfo.parsed_unit.unit.isNull()) { // second pass on non-static
        // instantiation context
        t_instantiation_context local_ictx = ictx;
        local_ictx.parameters.insert(nfo.specializations.parameters.begin(), nfo.specializations.parameters.end());
        // create local context
        makeBlueprintInstantiationContext(nfo, local_ictx, local_ictx);
        // record the specializations
        nfo.specializations = local_ictx;
        // write as module
        nfo.blueprint->writeAsModule(compiler, out, nfo.specializations, first_pass);
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::writeAsModule(SiliceCompiler *compiler, ostream& out, const t_instantiation_context& ictx, t_vio_ff_usage& _ff_usage, bool first_pass) const
{
  out << nxl;

  t_vio_ff_usage ff_input_bindings_usage;

  // write memory modules
  for (const auto& mem : m_Memories) {
    writeModuleMemory(ictx.instance_name, out, mem);
  }

  // module header
  out << "module M_" << m_Name + (ictx.instance_name.empty() ? "" : ("_" + ictx.instance_name)) + ' ';

  // list ports names
  out << '(' << nxl;
  for (const auto &v : m_Inputs) {
    out << string(ALG_INPUT) << '_' << v.name << ',' << nxl;
  }
  for (const auto &v : m_Outputs) {
    out << string(ALG_OUTPUT) << '_' << v.name << ',' << nxl;
  }
  for (const auto &v : m_InOuts) {
    out << string(ALG_INOUT) << '_' << v.name << ',' << nxl;
  }
  if (!isNotCallable() || m_TopMost /*keep for glue convenience*/) {
    out << ALG_INPUT << "_" << ALG_RUN << ',' << nxl;
  }
  if (!hasNoFSM() || m_TopMost /*keep for glue convenience*/) {
    out << ALG_OUTPUT << "_" << ALG_DONE << ',' << nxl;
  }
  if (requiresReset() || m_TopMost /*keep for glue convenience*/) {
    out << ALG_RESET "," << nxl;
  }
  out << "out_" << ALG_CLOCK "," << nxl;
  out << ALG_CLOCK << nxl;
  out << ");" << nxl;
  // declare ports
  for (const auto& v : m_Inputs) {
    sl_assert(v.table_size == 0);
    writeVerilogDeclaration(out, ictx, "input", v, string(ALG_INPUT) + "_" + v.name );
  }
  for (const auto& v : m_Outputs) {
    sl_assert(v.table_size == 0);
    writeVerilogDeclaration(out, ictx, "output", v, string(ALG_OUTPUT) + "_" + v.name);
  }
  for (const auto& v : m_InOuts) {
    sl_assert(v.table_size == 0);
    writeVerilogDeclaration(out, ictx, "inout", v, string(ALG_INOUT) + "_" + v.name);
  }
  if (!isNotCallable() || m_TopMost) {
    out << "input " << ALG_INPUT << "_" << ALG_RUN << ';' << nxl;
  }
  if (!hasNoFSM() || m_TopMost) {
    out << "output " << ALG_OUTPUT << "_" << ALG_DONE << ';' << nxl;
  }
  if (requiresReset() || m_TopMost) {
    out << "input " ALG_RESET ";" << nxl;
  }
  out << "output out_" ALG_CLOCK << ";" << nxl;
  out << "input " ALG_CLOCK << ";" << nxl;

  // assign algorithm clock to output clock
  {
    t_vio_dependencies _1, _2;
    out << "assign out_" ALG_CLOCK << " = "
      << rewriteIdentifier("_", m_Clock, "", nullptr, ictx, t_source_loc(), FF_Q, true, _1, ff_input_bindings_usage)
      << ';' << nxl;
  }

  // blueprint instantiations (1/2)
  // -> required wires to hold outputs
  for (const auto& bpiordr : m_InstancedBlueprintsInDeclOrder) {
    const auto &nfo = m_InstancedBlueprints.at(bpiordr);
    // output wires
    for (const auto& os : nfo.blueprint->outputs()) {
      sl_assert(os.table_size == 0);
      // this uses the instantiated blueprint to determine the type of the wire,
      // since everything is determined by this point
      writeVerilogDeclaration(nfo.blueprint.raw(), out, nfo.specializations, "wire", os, std::string(WIRE) + nfo.instance_prefix + '_' + os.name);
    }
    // algorithm specific
    Algorithm *alg = dynamic_cast<Algorithm*>(nfo.blueprint.raw());
    if (alg != nullptr) {
      if (!alg->hasNoFSM()) {
        // algorithm done
        out << "wire " << WIRE << nfo.instance_prefix << '_' << ALG_DONE << ';' << nxl;
      }
    }
  }

  // memory instantiations (1/2)
  for (const auto& mem : m_Memories) {
    // output wires
    for (const auto& ouv : mem.out_vars) {
      const auto& os = m_Vars[m_VarNames.at(ouv.second)];
      writeVerilogDeclaration(out, ictx, "wire", os, std::string(WIRE) + "_mem_" + os.name);
    }
  }

  // const declarations
  writeConstDeclarations("_", out, ictx);

  // temporary vars declarations
  writeTempDeclarations("_", out, ictx);

  // wire declaration (vars bound to inouts)
  writeWireDeclarations("_", out, ictx);

  // flip-flops declarations
  writeFlipFlopDeclarations("_", out, ictx);

  // output assignments
  for (const auto& v : m_Outputs) {
    sl_assert(v.table_size == 0);
    if (v.usage == e_FlipFlop) {
      out << "assign " << ALG_OUTPUT << "_" << v.name << " = ";
      out << (v.combinational ? FF_D : FF_Q);
      out << "_" << v.name << ';' << nxl;
      if (v.combinational) {
        updateFFUsage(e_D, true, ff_input_bindings_usage.ff_usage[v.name]);
      } else {
        updateFFUsage(e_Q, true, ff_input_bindings_usage.ff_usage[v.name]);
      }
    } else if (v.usage == e_Temporary) {
        out << "assign " << ALG_OUTPUT << "_" << v.name << " = " << FF_TMP << "_" << v.name << ';' << nxl;
    } else if (v.usage == e_Bound) {
        out << "assign " << ALG_OUTPUT << "_" << v.name << " = " << rewriteBinding(v.name, nullptr, ictx) << ';' << nxl;
    } else {
      throw Fatal("internal error (output assignments)");
    }
  }

  // algorithm done
  if (!hasNoFSM()) {
    // track whenever algorithm reaches termination
    if (m_AutoRun) {
      out << "assign " << ALG_OUTPUT << "_" << ALG_DONE << " = (" << FF_Q << "_" << ALG_IDX << " == " << toFSMState(terminationState()) << ") & _" << ALG_AUTORUN << ";" << nxl;
    } else {
      out << "assign " << ALG_OUTPUT << "_" << ALG_DONE << " = (" << FF_Q << "_" << ALG_IDX << " == " << toFSMState(terminationState()) << ");" << nxl;
    }
  } else if (m_TopMost) {
    // a top most always will never be done
    out << "assign " << ALG_OUTPUT << "_" << ALG_DONE << " = 0;" << nxl;
  }

  // blueprint instantiations (2/2)
  for (const auto& ibiordr : m_InstancedBlueprintsInDeclOrder) {
    const auto &nfo = m_InstancedBlueprints.at(ibiordr);
    // module name
    if (compiler->isStaticBlueprint(nfo.blueprint_name).isNull()) {
      out << nfo.blueprint->moduleName(nfo.blueprint_name, ictx.instance_name + '_' + nfo.instance_name) << ' ';
    } else {
      out << nfo.blueprint->moduleName(nfo.blueprint_name, "") << ' ';
    }
    // instance name
    out << nfo.instance_name << ' ';
    // ports
    out << '(' << nxl;
    bool first = true;
    // inputs
    for (const auto &is : nfo.blueprint->inputs()) {
      if (!first) { out << ',' << nxl; } first = false;
      out << '.' << nfo.blueprint->inputPortName(is.name) << '(';
      if (nfo.boundinputs.count(is.name) > 0) {
        // input is bound, directly map bound VIO
        t_vio_dependencies _;
        if (std::holds_alternative<std::string>(nfo.boundinputs.at(is.name).first)) {
          std::string bndid = std::get<std::string>(nfo.boundinputs.at(is.name).first);
          out << rewriteIdentifier("_", bndid, "", nullptr, ictx, nfo.srcloc,
            nfo.boundinputs.at(is.name).second == e_Q ? FF_Q : FF_D, true, _, ff_input_bindings_usage,
            nfo.boundinputs.at(is.name).second == e_Q ? e_Q : e_D
          );
        } else {
          writeAccess("_", out, false, std::get<siliceParser::AccessContext*>(nfo.boundinputs.at(is.name).first),
            -1, nullptr, ictx,
            nfo.boundinputs.at(is.name).second == e_Q ? FF_Q : FF_D, _, ff_input_bindings_usage
          );
        }
        // check whether the bound variable is a wire, an input, or another bound var, in which case <:: does not make sense
        if (nfo.boundinputs.at(is.name).second == e_Q) {
          std::string bid;
          if (std::holds_alternative<std::string>(nfo.boundinputs.at(is.name).first)) {
            bid = std::get<std::string>(nfo.boundinputs.at(is.name).first);
          } else {
            bid = determineAccessedVar(std::get<siliceParser::AccessContext*>(nfo.boundinputs.at(is.name).first),nullptr);
          }
          const auto &vio = m_VIOBoundToBlueprintOutputs.find(bid);
          bool bound_wire_input = false;
          if (vio != m_VIOBoundToBlueprintOutputs.end()) {
            bound_wire_input = true;
          }
          if (m_WireAssignmentNames.count(bid) > 0) {
            bound_wire_input = true;
          }
          if (isInput(bid)) {
            bound_wire_input = true;
          }
          if (bound_wire_input) {
            reportError(nfo.srcloc, "using <:: on input, tracked expression or bound vio '%s' has no effect, use <: instead", bid.c_str());
          }
        }
      } else {
        auto vname = nfo.instance_prefix + "_" + is.name;
        // input is not bound and assigned in logic, a specific flip-flop is created for this
        if (nfo.blueprint->isNotCallable() && !nfo.instance_reginput) {
          // the instance is never called, we bind to D
          t_vio_dependencies _;
          out << rewriteIdentifier("_", vname, "", nullptr, ictx, nfo.srcloc, FF_D, true, _, ff_input_bindings_usage);
        } else {
          // the instance is only called or registered input were required, we bind to Q
          t_vio_dependencies _;
          out << rewriteIdentifier("_", vname, "", nullptr, ictx, nfo.srcloc, FF_Q, true, _, ff_input_bindings_usage);
        }
      }
      out << ')';
    }
    // outputs (wire)
    for (const auto& os : nfo.blueprint->outputs()) {
      if (!first) { out << ',' << nxl; } first = false;
      out << '.'
        << nfo.blueprint->outputPortName(os.name)
        << '(' << WIRE << nfo.instance_prefix << '_' << os.name << ')';
    }
    // inouts (host algorithm inout or wire)
    for (const auto& os : nfo.blueprint->inOuts()) {
      if (!first) { out << ',' << nxl; } first = false;
      std::string bindpoint = nfo.instance_prefix + "_" + os.name;
      const auto& vio = m_BlueprintInOutsBoundToVIO.find(bindpoint);
      if (vio != m_BlueprintInOutsBoundToVIO.end()) {
        if (isInOut(vio->second)) {
          out << '.' << nfo.blueprint->inoutPortName(os.name) << '(' << ALG_INOUT << "_" << vio->second << ")";
        } else {
          out << '.' << nfo.blueprint->inoutPortName(os.name) << '(' << WIRE << "_" << vio->second << ")";
        }
      } else {
        reportError(nfo.srcloc, "cannot find algorithm inout binding '%s'", os.name.c_str());
      }
    }
    // algorithm specific
    Algorithm *alg = dynamic_cast<Algorithm*>(nfo.blueprint.raw());
    if (alg != nullptr) {
      if (!alg->hasNoFSM()) {
        if (!first) { out << ',' << nxl; } first = false;
        // done
        out << '.' << ALG_OUTPUT << '_' << ALG_DONE
          << '(' << WIRE << nfo.instance_prefix << '_' << ALG_DONE << ')';
      }
      if (!alg->isNotCallable()) {
        if (!first) { out << ',' << nxl; } first = false;
        // run
        out << '.' << ALG_INPUT << '_' << ALG_RUN
          << '(' << nfo.instance_prefix << '_' << ALG_RUN << ')';
      }
    }
    // reset
    if (nfo.blueprint->requiresReset()) {
      if (!first) { out << ',' << nxl; } first = false;
      t_vio_dependencies _;
      out << '.' << ALG_RESET << '(' << rewriteIdentifier("_", nfo.instance_reset, "", nullptr, ictx, nfo.srcloc, FF_Q, true, _, ff_input_bindings_usage) << ")";
    }
    // clock
    if (nfo.blueprint->requiresClock()) {
      t_vio_dependencies _;
      if (!first) { out << ',' << nxl; } first = false;
      out << '.' << ALG_CLOCK << '(' << rewriteIdentifier("_", nfo.instance_clock, "", nullptr, ictx, nfo.srcloc, FF_Q, true, _, ff_input_bindings_usage) << ")";
    }
    // end of instantiation
    out << ");" << nxl;
  }
  out << nxl;

  // determine always dependencies on unregistered inputs/outputs due to blueprint bindings
  t_vio_dependencies always_dependencies;
  for (const auto& ibiordr : m_InstancedBlueprintsInDeclOrder) {
    const auto &nfo = m_InstancedBlueprints.at(ibiordr);
    // no combinational dependencies if inputs are registered or instance is callable (inputs bound to Q)
    if (!nfo.blueprint->isNotCallable() || nfo.instance_reginput) {
      continue;
    }
    // find out sets of combinational inputs and outputs
    unordered_set<string> unreg_input_bindings;  // bindings to unreg input
    unordered_set<string> unreg_output_bindings; // bindings to unreg output
    for (const auto &b : nfo.bindings) {
      if (b.dir == e_LeftQ) {
        // registered input, skip
        continue;
      } else if (b.dir == e_Left) {
        // unregistered input, possible dependency
        unreg_input_bindings.insert(bindingRightIdentifier(b));
      } else if (b.dir == e_Right) {
        if (nfo.blueprint->output(b.left).combinational && !nfo.blueprint->output(b.left).combinational_nocheck) {
          // unregistered output, possible dependency
          unreg_output_bindings.insert(bindingRightIdentifier(b));
        }
      }
    }
    // add to the list of inputs all unbounded one (dot syntax) NOTE: we already checked inputs are not registered
    for (const auto &is : nfo.blueprint->inputs()) {
      auto vname = nfo.instance_prefix + "_" + is.name;
      unreg_input_bindings.insert(vname);
    }
    // add to the list of outputs all unbounded one that are combinational
    for (const auto &os : nfo.blueprint->outputs()) {
      if (nfo.blueprint->output(os.name).combinational && !nfo.blueprint->output(os.name).combinational_nocheck) {
        auto vname = nfo.instance_prefix + "_" + os.name;
        unreg_output_bindings.insert(vname);
      }
    }
    // update dependencies and run checks
    updateAndCheckDependencies(always_dependencies, nfo.srcloc, unreg_input_bindings, unreg_output_bindings, nullptr);
    // since we are only dealing with combinational connections (not registered) we perform
    // an additional check at this stage: no vio should depend on self, or this is for sure a cycle
    // (with registered vios a first dependency is ok since this is on the Q side of the flip-flop)
    for (const auto& d : always_dependencies.dependencies) {
      if (d.second.count(d.first) > 0) {
        // yes: this would produce a combinational cycle, error!
        string msg = "bindings leads to a combinational cycle (variable: '%s')\n\n";
        reportError(nfo.srcloc, msg.c_str(), d.first.c_str());
      }
    }
  }

  /// DEBUG
  if (0) {
    std::cerr << "---- always dependencies\n";
    for (auto w : always_dependencies.dependencies) {
      std::cerr << "var " << w.first << " depds on ";
      for (auto r : w.second) {
        std::cerr << r << ' ';
      }
      std::cerr << nxl;
    }
    std::cerr << nxl;
  }

  // memory instantiations (2/2)
  for (const auto& mem : m_Memories) {
    // module
    out << memoryModuleName(ictx.instance_name,mem) << " __mem__" << mem.name << '(' << nxl;
    // clocks
    if (mem.clocks.empty()) {
      if (mem.mem_type == DUALBRAM || mem.mem_type == SIMPLEDUALBRAM) {
        t_vio_dependencies _1,_2;
        out << ".clock0(" << rewriteIdentifier("_", m_Clock, "", nullptr, ictx, mem.srcloc, FF_Q, true, _1, ff_input_bindings_usage) << ")," << nxl;
        out << ".clock1(" << rewriteIdentifier("_", m_Clock, "", nullptr, ictx, mem.srcloc, FF_Q, true, _2, ff_input_bindings_usage) << ")," << nxl;
      } else {
        t_vio_dependencies _;
        out << ".clock("  << rewriteIdentifier("_", m_Clock, "", nullptr, ictx, mem.srcloc, FF_Q, true, _, ff_input_bindings_usage) << ")," << nxl;
      }
    } else {
      sl_assert((mem.mem_type == DUALBRAM || mem.mem_type == SIMPLEDUALBRAM) && mem.clocks.size() == 2);
      std::string clk0 = mem.clocks[0];
      std::string clk1 = mem.clocks[1];
      t_vio_dependencies _1, _2;
      out << ".clock0(" << rewriteIdentifier("_", clk0, "", nullptr, ictx, mem.srcloc, FF_Q, true, _1, ff_input_bindings_usage) << ")," << nxl;
      out << ".clock1(" << rewriteIdentifier("_", clk1, "", nullptr, ictx, mem.srcloc, FF_Q, true, _2, ff_input_bindings_usage) << ")," << nxl;
    }
    // inputs
    for (const auto& inv : mem.in_vars) {
      t_vio_dependencies _;
      out << '.' << ALG_INPUT << '_' << inv.first << '(' << rewriteIdentifier("_", inv.second, "", nullptr, ictx, mem.srcloc, mem.delayed ? FF_Q : FF_D, true, _, ff_input_bindings_usage,
        mem.delayed ? e_Q : e_D
      ) << ")," << nxl;
    }
    // output wires
    int num = (int)mem.out_vars.size();
    for (const auto& ouv : mem.out_vars) {
      out << '.' << ALG_OUTPUT << '_' << ouv.first << '(' << WIRE << "_mem_" << ouv.second << ')';
      if (num-- > 1) {
        out << ',' << nxl;
      } else {
        out << nxl;
      }
    }
    // end of instantiation
    out << ");" << nxl;
  }
  out << nxl;

  // inouts used in algorithm
  for (const auto &io : m_InOuts) {
    if (m_VIOToBlueprintInOutsBound.count(io.name) == 0) {
      string wdth = varBitWidth(io, ictx).c_str();
      if (!is_number(wdth)) {
        reportError(io.srcloc, "cannot find width of '%s' during instantiation of unit '%s'", io.name.c_str(), m_Name.c_str());
      }
      int width = atoi(wdth.c_str());
      // output used?
      if ( m_Vars.at(m_VarNames.at(io.name + "_o")).access       != e_NotAccessed
        || m_Vars.at(m_VarNames.at(io.name + "_oenable")).access != e_NotAccessed) {
        // write bit by bit ternary assignment
        for (int b = 0; b < width; ++b) {
          out << "assign " << ALG_INOUT << "_" << io.name << "[" << std::to_string(b) << "] = ";
          t_vio_dependencies _1, _2, _3;
          if (m_Vars.at(m_VarNames.at(io.name + "_oenable")).access != e_NotAccessed) {
            out << rewriteIdentifier("_", io.name + "_oenable", "[" + std::to_string(b) + "]", nullptr, ictx, io.srcloc, FF_Q, true, _1, ff_input_bindings_usage);
          } else {
            out << "1'b0";
          }
          out << " ? ";
          if (m_Vars.at(m_VarNames.at(io.name + "_o")).access != e_NotAccessed) {
            out << rewriteIdentifier("_", io.name + "_o", "[" + std::to_string(b) + "]", nullptr, ictx, io.srcloc, FF_Q, true, _1, ff_input_bindings_usage);
          } else {
            out << "1'b0";
          }
          out << " : 1'bz;" << nxl;
        }
      } else {
        out << "assign " << ALG_INOUT << "_" << io.name << " = {" << width << "{1'bz}};" << nxl;
      }
      // assign wire if used
      if (m_Vars.at(m_VarNames.at(io.name + "_i")).access != e_NotAccessed) {
        out << "assign " << WIRE << "_" << io.name + "_i" << " = " << ALG_INOUT << "_" << io.name << ';' << nxl;
      }
    }
  }

  // track dependencies
  t_vio_dependencies post_dependencies;

  // wire assignments
  // NOTE: wires also produce D usage that is to be considered as an input binding
  writeWireAssignements("_", out, ictx, always_dependencies, ff_input_bindings_usage, first_pass);

  // split the input bindings usage into pre / post
  // Q are considered read at cycle start ('top' of the cycle circuit)
  // D are considered read at cycle end   ('bottom' of the cycle circuit)
  vector<t_vio_ff_usage> post_ff_usage;
  post_ff_usage.push_back(t_vio_ff_usage());
  for (auto &v : ff_input_bindings_usage.ff_usage) {
    if (v.second & e_D) {
      post_ff_usage.back().ff_usage[v.first] = e_D;
    }
    if (v.second & e_Q) {
      _ff_usage.ff_usage[v.first] = e_Q;
    }
  }

  // correctly setup the formal stuff:
  //   - reset on the initial state
  //   - always assume that the algorithm is either running or finished

  out << "`ifdef FORMAL" << nxl
    << "initial begin" << nxl
    << "assume(" << ALG_RESET << ");" << nxl
    << "end" << nxl;
  if (!hasNoFSM()) {
    if (!isNotCallable()) {
      out << "assume property($initstate || (" << ALG_INPUT << "_" << ALG_RUN << " || " << ALG_OUTPUT << "_" << ALG_DONE << "));" << nxl;
    } else {
      out << "assume property($initstate || (" << ALG_OUTPUT << "_" << ALG_DONE << "));" << nxl;
    }
  }
  out << "`endif" << nxl;

  // combinational
  out << "always @* begin" << nxl;
  writeCombinationalAlwaysPre("_", out, ictx, always_dependencies, _ff_usage, post_dependencies);
  if (!hasNoFSM()) {
    // write all states
    writeCombinationalStates("_", out, ictx, always_dependencies, _ff_usage, post_dependencies);
  }
  // always after block
  {
    /*for (auto ff : post_dependencies.dependencies) {
      cerr << "***********************" << ff.first << " - ";
      for (auto d : ff.second) {
        cerr << d << ',';
      }
      cerr << std::endl;
    }*/
    std::queue<size_t> q;
    std::set<v2i>      lines;
    t_vio_dependencies _; // unusued
    writeStatelessBlockGraph("_", out, ictx, &m_AlwaysPost, nullptr, q, post_dependencies, _ff_usage, _, lines);
    clearNoLatchFFUsage(_ff_usage);
  }
  out << "end" << nxl;

  combineFFUsageInto(nullptr, _ff_usage, post_ff_usage, _ff_usage);
  clearNoLatchFFUsage(_ff_usage);

#if 0
  std::cerr << " === usage for algorithm " << m_Name << " ====" << nxl;
  for (const auto &v : _ff_usage.ff_usage) {
    std::cerr << "vio " << v.first << " : ";
    if (v.second & e_D) {
      std::cerr << "D";
    }
    if (v.second & e_Q) {
      std::cerr << "Q";
    }
    if (v.second & e_Latch) {
      std::cerr << "latch";
    }
    std::cerr << nxl;
  }
#endif

  // flip-flops update
  writeFlipFlops("_", out, ictx);

  out << nxl;

  out << "endmodule" << nxl;
  out << nxl;
}

// -------------------------------------------------

void Algorithm::outputFSMGraph(std::string dotFile) const
{
  ofstream out(dotFile);
  //cerr << "==========================================================" << nxl;
  //cerr << dotFile << nxl;
  //cerr << "==========================================================" << nxl;
  out << "digraph D {" << nxl;
  for (auto b : m_Blocks) {
    if (b->state_id < 0) { continue; }
    out << "st_" << toFSMState(b->state_id) << "[label = \"State " << toFSMState(b->state_id) << "\n" << b->block_name << "\"];" << nxl;
    std::set<int> nexts;
    //cerr << "STATE " << b->block_name << " state_id = " << b->state_id << nxl;
    //cerr << b->end_action_name() << nxl;
    std::vector< t_combinational_block * > children;
    b->getChildren(children);
    //for (auto c : children) {
    //  cerr << "   CHILD " << c->block_name << " state_id = " << c->state_id << nxl;
    //}
    std::set<t_combinational_block*> leaves;
    findNonCombinationalLeaves(b, leaves);
    for (auto other : leaves) {
      nexts.insert(toFSMState(fastForward(other)->state_id));
    }
    for (auto N : nexts) {
       out << "st_" << toFSMState(b->state_id) << " -> " << "st_" << N << ';' << nxl;
    }
  }
  out << "}" << nxl;
}

// -------------------------------------------------

void Algorithm::outputVIOReport(const t_instantiation_context &ictx) const
{
  std::ofstream freport(vioReportName(), std::ios_base::app);

  freport << (ictx.instance_name.empty()?"__main":ictx.instance_name) << " " << (m_Vars.size() + m_Outputs.size() + m_Inputs.size()) << " " << nxl;
  for (auto &v : m_Vars) {
    auto tk = getToken(v.srcloc.root, v.srcloc.interval);
    std::string tk_text = v.name;
    int         tk_line = -1;
    if (tk) {
      std::pair<std::string, int> fl = getTokenSourceFileAndLine(v.srcloc.root, tk);
      tk_text = tk->getText();
      tk_line = fl.second;
    }
    freport
      << tk_text << " "
      << v.name << " "
      << tk_line << " "
      << "var "
      ;
    switch (v.usage) {
    case e_Undetermined: freport << "undetermined #"; break;
    case e_NotUsed:      freport << "notused #"; break;
    case e_Const:        freport << "const " << FF_CST << '_' << v.name; break;
    case e_Temporary:    freport << "temp " << FF_TMP << '_' << v.name; break;
    case e_FlipFlop:     freport << "ff " << FF_D << '_' << v.name << ',' << FF_Q << '_' << v.name; break;
    case e_Bound:        freport << "bound " << WIRE << '_' << v.name; break;
    case e_Wire:         freport << "wire " << WIRE << '_' << v.name; break;
    }
    freport << nxl;
  }
  for (auto &v : m_Outputs) {
    auto tk = getToken(v.srcloc.root,v.srcloc.interval);
    std::string tk_text = v.name;
    int         tk_line = -1;
    if (tk) {
      std::pair<std::string, int> fl = getTokenSourceFileAndLine(v.srcloc.root, tk);
      tk_text = tk->getText();
      tk_line = fl.second;
    }
    freport
      << tk_text << " "
      << v.name << " "
      << tk_line << " "
      << "output ";
    switch (v.usage) {
    case e_Undetermined: freport << "undetermined #"; break;
    case e_NotUsed:      freport << "notused #"; break;
    case e_Const:        freport << "const " << FF_CST << '_' << v.name; break;
    case e_Temporary:    freport << "temp " << FF_TMP << '_' << v.name; break;
    case e_FlipFlop:     freport << "ff " << FF_D << '_' << v.name << ',' << FF_Q << '_' << v.name; break;
    case e_Bound:        freport << "bound " << WIRE << '_' << v.name; break;
    case e_Wire:         freport << "wire " << WIRE << '_' << v.name; break;
    }
    freport << nxl;
  }
  for (auto &v : m_Inputs) {
    auto tk = getToken(v.srcloc.root, v.srcloc.interval);
    std::string tk_text = v.name;
    int         tk_line = -1;
    if (tk) {
      std::pair<std::string, int> fl = getTokenSourceFileAndLine(v.srcloc.root, tk);
      tk_text = tk->getText();
      tk_line = fl.second;
    }
    freport
      << tk_text << " "
      << v.name << " "
      << tk_line << " "
      << "input wire " << ALG_INPUT << '_' << v.name;
    freport << nxl;
  }
}

// -------------------------------------------------

void Algorithm::enableReporting(std::string reportname)
{
  m_ReportBaseName = reportname;
  for (auto bp : m_InstancedBlueprints) {
    Algorithm *alg = dynamic_cast<Algorithm*>(bp.second.blueprint.raw());
    if (alg != nullptr) {
      alg->enableReporting(reportname);
    }
  }
}

// -------------------------------------------------
