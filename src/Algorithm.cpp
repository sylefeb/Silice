/*

    Silice FPGA language and compiler
    (c) Sylvain Lefebvre - @sylefeb

This work and all associated files are under the

     GNU AFFERO GENERAL PUBLIC LICENSE
        Version 3, 19 November 2007

With the additional clause that the copyright notice
above, identitfying the author and original copyright
holder must remain included in all distributions.

(header_1_0)
*/
// -------------------------------------------------
//                                ... hardcoding ...
// -------------------------------------------------

#include "Algorithm.h"
#include "Module.h"
#include "Config.h"
#include "VerilogTemplate.h"
#include "ExpressionLinter.h"

#include <cctype>

using namespace std;
using namespace antlr4;
using namespace Silice;

#define SUB_ENTRY_BLOCK "__sub_"

// -------------------------------------------------

void Algorithm::reportError(antlr4::Token *what, int line, const char *msg, ...) const
{
  const int messageBufferSize = 4096;
  char message[messageBufferSize];

  va_list args;
  va_start(args, msg);
  vsprintf_s(message, messageBufferSize, msg, args);
  va_end(args);

  throw LanguageError(line, what, antlr4::misc::Interval::INVALID, message);
}

// -------------------------------------------------

void Algorithm::reportError(antlr4::misc::Interval interval, int line, const char *msg, ...) const
{
  const int messageBufferSize = 4096;
  char message[messageBufferSize];

  va_list args;
  va_start(args, msg);
  vsprintf_s(message, messageBufferSize, msg, args);
  va_end(args);

  throw LanguageError(line, nullptr,interval, message);
}

// -------------------------------------------------

void Algorithm::checkModulesBindings() const
{
  for (auto& im : m_InstancedModules) {
    for (const auto& b : im.second.bindings) {
      bool is_input  = (im.second.mod->inputs() .find(b.left) != im.second.mod->inputs().end());
      bool is_output = (im.second.mod->outputs().find(b.left) != im.second.mod->outputs().end());
      bool is_inout  = (im.second.mod->inouts() .find(b.left) != im.second.mod->inouts().end());
      if (!is_input && !is_output && !is_inout) {
        reportError(nullptr, b.line, "wrong binding point (neither input nor output), instanced module '%s', binding '%s'",
          im.first.c_str(), b.left.c_str());
      }
      if ((b.dir == e_Left || b.dir == e_LeftQ) && !is_input) { // input
        reportError(nullptr, b.line, "wrong binding direction, instanced module '%s', binding output '%s'",
          im.first.c_str(), b.left.c_str());
      }
      if (b.dir == e_Right && !is_output) { // output
        reportError(nullptr, b.line, "wrong binding direction, instanced module '%s', binding input '%s'",
          im.first.c_str(), b.left.c_str());
      }
      // check right side
      if (!isInputOrOutput(bindingRightIdentifier(b)) && !isInOut(bindingRightIdentifier(b))
        && m_VarNames.count(bindingRightIdentifier(b)) == 0
        && bindingRightIdentifier(b) != m_Clock && bindingRightIdentifier(b) != ALG_CLOCK
        && bindingRightIdentifier(b) != m_Reset && bindingRightIdentifier(b) != ALG_RESET) {
        reportError(nullptr, b.line, "wrong binding point, instanced module '%s', binding to '%s'",
          im.first.c_str(), bindingRightIdentifier(b).c_str());
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::checkAlgorithmsBindings() const
{
  for (auto& ia : m_InstancedAlgorithms) {
    set<string> inbound;
    for (const auto& b : ia.second.bindings) {
      // check left side
      bool is_input  = ia.second.algo->isInput (b.left);
      bool is_output = ia.second.algo->isOutput(b.left);
      bool is_inout  = ia.second.algo->isInOut (b.left);
      if (!is_input && !is_output && !is_inout) {
        reportError(nullptr, b.line, "wrong binding point (neither input nor output), instanced algorithm '%s', binding '%s'",
          ia.first.c_str(), b.left.c_str());
      }
      if ((b.dir == e_Left || b.dir == e_LeftQ) && !is_input) { // input
        reportError(nullptr, b.line, "wrong binding direction, instanced algorithm '%s', binding output '%s'",
          ia.first.c_str(), b.left.c_str());
      }
      if (b.dir == e_Right && !is_output) { // output
        reportError(nullptr, b.line, "wrong binding direction, instanced algorithm '%s', binding input '%s'",
          ia.first.c_str(), b.left.c_str());
      }
      if (b.dir == e_BiDir && !is_inout) { // inout
        reportError(nullptr, b.line, "wrong binding direction, instanced algorithm '%s', binding inout '%s'",
          ia.first.c_str(), b.left.c_str());
      }
      // check right side
      std::string br = bindingRightIdentifier(b);
      // check existence
      if (!isInputOrOutput(br) && !isInOut(br)
        && m_VarNames.count(br) == 0
        && br != m_Clock && br != ALG_CLOCK
        && br != m_Reset && br != ALG_RESET) {
        reportError(nullptr, b.line, "wrong binding point, instanced algorithm '%s', binding '%s' to '%s'",
          ia.first.c_str(), br.c_str(), b.left.c_str());
      }
      if (b.dir == e_Left || b.dir == e_LeftQ) {
        // track inbound
        inbound.insert(br);
      }
      // lint
      ExpressionLinter linter(this);
      linter.lintBinding(
        sprint("instanced algorithm '%s', binding '%s' to '%s'", ia.first.c_str(), br.c_str(), b.left.c_str()),
        b.dir,b.line,
        get<0>(ia.second.algo->determineVIOTypeWidthAndTableSize(nullptr, b.left, -1)),
        get<0>(determineVIOTypeWidthAndTableSize(nullptr, br, -1))
      );
    }
    // check no binding appears with both directions (excl. inout)
    for (const auto &b : ia.second.bindings) {
      std::string br = bindingRightIdentifier(b);
      if (b.dir == e_Right) {
        if (inbound.count(br) > 0) {
          reportError(nullptr, b.line, "binding appears both as input and output on the same instance, instanced algorithm '%s', bound vio '%s'",
            ia.first.c_str(), br.c_str());
        }
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::autobindInstancedModule(t_module_nfo& _mod)
{
  // -> set of already defined bindings
  set<std::string> defined;
  for (auto b : _mod.bindings) {
    defined.insert(b.left);
  }
  // -> for each module inputs
  for (auto io : _mod.mod->inputs()) {
    if (defined.find(io.first) == defined.end()) {
      // not bound, check if algorithm has an input with same name
      if (m_InputNames.find(io.first) != m_InputNames.end()) {
        // yes: autobind
        t_binding_nfo bnfo;
        bnfo.line  = _mod.instance_line;
        bnfo.left  = io.first;
        bnfo.right_identifier = io.first;
        bnfo.dir = e_Left;
        _mod.bindings.push_back(bnfo);
      }
      // check if algorithm has a var with same name
      else {
        if (m_VarNames.find(io.first) != m_VarNames.end()) {
          // yes: autobind
          t_binding_nfo bnfo;
          bnfo.line = _mod.instance_line;
          bnfo.left = io.first;
          bnfo.right_identifier = io.first;
          bnfo.dir = e_Left;
          _mod.bindings.push_back(bnfo);
        }
      }
    }
  }
  // -> internals (clock and reset)
  std::vector<std::string> internals;
  internals.push_back(ALG_CLOCK);
  internals.push_back(ALG_RESET);
  for (auto io : internals) {
    if (defined.find(io) == defined.end()) {
      // not bound, check if module has an input with same name
      if (_mod.mod->inputs().find(io) != _mod.mod->inputs().end()) {
        // yes: autobind
        t_binding_nfo bnfo;
        bnfo.line = _mod.instance_line;
        bnfo.left = io;
        bnfo.right_identifier = io;
        bnfo.dir = e_Left;
        _mod.bindings.push_back(bnfo);
      }
    }
  }
  // -> for each module output
  for (auto io : _mod.mod->outputs()) {
    if (defined.find(io.first) == defined.end()) {
      // not bound, check if algorithm has an output with same name
      if (m_OutputNames.find(io.first) != m_OutputNames.end()) {
        // yes: autobind
        t_binding_nfo bnfo;
        bnfo.line = _mod.instance_line;
        bnfo.left = io.first;
        bnfo.right_identifier = io.first;
        bnfo.dir = e_Right;
        _mod.bindings.push_back(bnfo);
      }
      // check if algorithm has a var with same name
      else {
        if (m_VarNames.find(io.first) != m_VarNames.end()) {
          // yes: autobind
          t_binding_nfo bnfo;
          bnfo.line = _mod.instance_line;
          bnfo.left = io.first;
          bnfo.right_identifier = io.first;
          bnfo.dir = e_Right;
          _mod.bindings.push_back(bnfo);
        }
      }
    }
  }
  // -> for each module inout
  for (auto io : _mod.mod->inouts()) {
    if (defined.find(io.first) == defined.end()) {
      // not bound
      // check if algorithm has an inout with same name
      if (m_InOutNames.find(io.first) != m_InOutNames.end()) {
        // yes: autobind
        t_binding_nfo bnfo;
        bnfo.line = _mod.instance_line;
        bnfo.left = io.first;
        bnfo.right_identifier = io.first;
        bnfo.dir = e_BiDir;
        _mod.bindings.push_back(bnfo);
      }
      // check if algorithm has a var with same name
      else {
        if (m_VarNames.find(io.first) != m_VarNames.end()) {
          // yes: autobind
          t_binding_nfo bnfo;
          bnfo.line = _mod.instance_line;
          bnfo.left = io.first;
          bnfo.right_identifier = io.first;
          bnfo.dir = e_BiDir;
          _mod.bindings.push_back(bnfo);
        }
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::autobindInstancedAlgorithm(t_algo_nfo& _alg)
{
  // -> set of already defined bindings
  set<std::string> defined;
  for (auto b : _alg.bindings) {
    defined.insert(b.left);
  }
  // -> for each algorithm inputs
  for (auto io : _alg.algo->m_Inputs) {
    if (defined.find(io.name) == defined.end()) {
      // not bound, check if host algorithm has an input with same name
      if (m_InputNames.find(io.name) != m_InputNames.end()) {
        // yes: autobind
        t_binding_nfo bnfo;
        bnfo.line = _alg.instance_line;
        bnfo.left = io.name;
        bnfo.right_identifier = io.name;
        bnfo.dir = e_Left;
        _alg.bindings.push_back(bnfo);
      } else // check if algorithm has a var with same name
        if (m_VarNames.find(io.name) != m_VarNames.end()) {
          // yes: autobind
          t_binding_nfo bnfo;
          bnfo.line = _alg.instance_line;
          bnfo.left = io.name;
          bnfo.right_identifier = io.name;
          bnfo.dir = e_Left;
          _alg.bindings.push_back(bnfo);
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
      if (_alg.algo->m_InputNames.find(io) != _alg.algo->m_InputNames.end()) {
        // yes: autobind
        t_binding_nfo bnfo;
        bnfo.line = _alg.instance_line;
        bnfo.left = io;
        bnfo.right_identifier = io;
        bnfo.dir = e_Left;
        _alg.bindings.push_back(bnfo);
      }
    }
  }
  // -> for each algorithm output
  for (auto io : _alg.algo->m_Outputs) {
    if (defined.find(io.name) == defined.end()) {
      // not bound, check if host algorithm has an output with same name
      if (m_OutputNames.find(io.name) != m_OutputNames.end()) {
        // yes: autobind
        t_binding_nfo bnfo;
        bnfo.line = _alg.instance_line;
        bnfo.left = io.name;
        bnfo.right_identifier = io.name;
        bnfo.dir = e_Right;
        _alg.bindings.push_back(bnfo);
      } else // check if algorithm has a var with same name
        if (m_VarNames.find(io.name) != m_VarNames.end()) {
          // yes: autobind
          t_binding_nfo bnfo;
          bnfo.line = _alg.instance_line;
          bnfo.left = io.name;
          bnfo.right_identifier = io.name;
          bnfo.dir = e_Right;
          _alg.bindings.push_back(bnfo);
        }
    }
  }
  // -> for each algorithm inout
  for (auto io : _alg.algo->m_InOuts) {
    if (defined.find(io.name) == defined.end()) {
      // not bound
      // check if algorithm has an inout with same name
      if (m_InOutNames.find(io.name) != m_InOutNames.end()) {
        // yes: autobind
        t_binding_nfo bnfo;
        bnfo.line = _alg.instance_line;
        bnfo.left = io.name;
        bnfo.right_identifier = io.name;
        bnfo.dir = e_BiDir;
        _alg.bindings.push_back(bnfo);
      }
      // check if algorithm has a var with same name
      else {
        if (m_VarNames.find(io.name) != m_VarNames.end()) {
          // yes: autobind
          t_binding_nfo bnfo;
          bnfo.line = _alg.instance_line;
          bnfo.left = io.name;
          bnfo.right_identifier = io.name;
          bnfo.dir = e_BiDir;
          _alg.bindings.push_back(bnfo);
        }
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::resolveInstancedAlgorithmBindingDirections(t_algo_nfo& _alg)
{
  std::vector<t_binding_nfo> cleanedup_bindings;
  for (auto& b : _alg.bindings) {
    if (b.dir == e_Auto || b.dir == e_AutoQ) {
      // input?
      if (_alg.algo->isInput(b.left)) {
        b.dir = (b.dir == e_Auto) ? e_Left : e_LeftQ;
      }
      // output?
      else if (_alg.algo->isOutput(b.left)) {
        b.dir = e_Right;
      }
      // inout?
      else if (_alg.algo->isInOut(b.left)) {
        b.dir = e_BiDir;
      } else {
        
        // group members is not used by algorithm, we allow this for flexibility,
        // in particular in conjunction with interfaces
        continue;

        //reportError(nullptr, b.line, "cannot determine binding direction for '%s <:> %s', binding to algorithm instance '%s'",
        //  b.left.c_str(), bindingRightIdentifier(b).c_str(), _alg.instance_name.c_str());
      }
    }
    cleanedup_bindings.push_back(b);
  }
  _alg.bindings = cleanedup_bindings;
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

bool Algorithm::isInput(std::string var) const
{
  return (m_InputNames.find(var) != m_InputNames.end());
}

// -------------------------------------------------

bool Algorithm::isOutput(std::string var) const
{
  return (m_OutputNames.find(var) != m_OutputNames.end());
}

// -------------------------------------------------

bool Algorithm::isInOut(std::string var) const
{
  return (m_InOutNames.find(var) != m_InOutNames.end());
}

// -------------------------------------------------

bool Algorithm::isInputOrOutput(std::string var) const
{
  return isInput(var) || isOutput(var);
}

// -------------------------------------------------

bool Algorithm::isVIO(std::string var) const
{
  return isInput(var) || isOutput(var) || isInOut(var) || m_VarNames.count(var) > 0;
}

// -------------------------------------------------

template<class T_Block>
Algorithm::t_combinational_block *Algorithm::addBlock(
  std::string name, const t_combinational_block* parent, const t_combinational_block_context *bctx, int line)
{
  auto B = m_State2Block.find(name);
  if (B != m_State2Block.end()) {
    reportError(nullptr, line, "state name '%s' already defined", name.c_str());
  }
  size_t next_id = m_Blocks.size();
  m_Blocks.emplace_back(new T_Block());
  m_Blocks.back()->block_name           = name;
  m_Blocks.back()->id                   = next_id;
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
    splitType(v->declarationVar()->TYPE()->getText(), tn);
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
    splitType(v->declarationVar()->TYPE()->getText(), tn);
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
    reportError(ifield->getSourceInterval(), (int)ifield->getStart()->getLine(), "unkown bitfield '%s'", ifield->field->getText().c_str());
  }
  // gather const values for each named entry
  unordered_map<string, pair<bool,string> > named_values;
  for (auto ne : ifield->namedValue()) {
    verifyMemberBitfield(ne->name->getText(), F->second, (int)ne->getStart()->getLine());
    named_values[ne->name->getText()] = make_pair(
      (ne->constValue()->CONSTANT() != nullptr), // true if sized constant
      gatherConstValue(ne->constValue()));
  }
  // verify we have all required fields, and only them
  if (named_values.size() != F->second->varList()->var().size()) {
    reportError(ifield->getSourceInterval(), (int)ifield->getStart()->getLine(), "incorrect number of names values in field initialization", ifield->field->getText().c_str());
  }
  // concatenate and rewrite as a single number with proper width
  int fwidth = bitfieldWidth(F->second);
  string concat = "{";
  int n = (int)F->second->varList()->var().size();
  for (auto v : F->second->varList()->var()) {
    auto ne = named_values.at(v->declarationVar()->IDENTIFIER()->getText());
    t_type_nfo tn;
    splitType(v->declarationVar()->TYPE()->getText(), tn);
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

std::string Algorithm::gatherConstValue(siliceParser::ConstValueContext* ival)
{
  if (ival->CONSTANT() != nullptr) {
    return rewriteConstant(ival->CONSTANT()->getText());
  } else if (ival->NUMBER() != nullptr) {
    std::string sign = ival->minus != nullptr ? "-" : "";
    return sign + ival->NUMBER()->getText();
  } else {
    sl_assert(false);
    return "";
  }
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

void Algorithm::insertVar(const t_var_nfo &_var, t_combinational_block *_current, bool no_init)
{
  t_subroutine_nfo *sub = nullptr;
  if (_current) {
    sub = _current->context.subroutine;
  }
  m_Vars.emplace_back(_var);
  m_VarNames.insert(std::make_pair(_var.name, (int)m_Vars.size() - 1));
  if (sub != nullptr) {
    sub->varnames.insert(std::make_pair(_var.name, (int)m_Vars.size() - 1));
  }
  if (!no_init) {
    // add to block initialization set
    _current->initialized_vars.insert(make_pair(_var.name, (int)m_Vars.size() - 1));
    _current->no_skip = true; // mark as cannot skip to honor var initializations
  }
  // add to block declared vios
  _current->declared_vios.insert(_var.name);
}

// -------------------------------------------------

void Algorithm::addVar(t_var_nfo& _var, t_combinational_block *_current, t_gather_context *_context, int line)
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
  // check for duplicates
  if (!isIdentifierAvailable(_var.name)) {
    reportError(nullptr, line, "variable '%s': this name is already used by a prior declaration", _var.name.c_str());
  }
  // ok!
  insertVar(_var, _current);
}

// -------------------------------------------------

void Algorithm::gatherVarNfo(siliceParser::DeclarationVarContext* decl, t_var_nfo& _nfo)
{
  _nfo.name = decl->IDENTIFIER()->getText();
  _nfo.table_size = 0;
  splitType(decl->TYPE()->getText(), _nfo.type_nfo);
  if (decl->value() != nullptr) {
    _nfo.init_values.push_back("0");
    _nfo.init_values[0] = gatherValue(decl->value());
  } else {
    if (decl->UNINITIALIZED() != nullptr) {
      _nfo.do_not_initialize = true;
    } else {
      reportError(decl->getSourceInterval(), (int)decl->getStart()->getLine(), "variable has no initializer, use '= uninitialized' if you really don't want to initialize it.");
    }
  }
  if (decl->ATTRIBS() != nullptr) {
    _nfo.attribs = decl->ATTRIBS()->getText();
  }
}

// -------------------------------------------------

void Algorithm::gatherDeclarationWire(siliceParser::DeclarationWireContext* wire, t_combinational_block *_current, t_gather_context *_context)
{
  t_var_nfo nfo;
  // checks
  if (wire->alwaysAssigned()->IDENTIFIER() == nullptr) {
    reportError(wire->getSourceInterval(), (int)wire->getStart()->getLine(), "improper wire declaration, has to be an identifier");
  }
  nfo.name = wire->alwaysAssigned()->IDENTIFIER()->getText();
  nfo.table_size = 0;
  nfo.do_not_initialize = true;
  nfo.usage = e_Wire;
  splitType(wire->TYPE()->getText(), nfo.type_nfo);
  // add var
  addVar(nfo, _current, _context, (int)wire->getStart()->getLine());
  // insert wire assignment
  m_WireAssignments.insert(make_pair(nfo.name,t_instr_nfo(wire->alwaysAssigned(),-1)));
}

// -------------------------------------------------

void Algorithm::gatherDeclarationVar(siliceParser::DeclarationVarContext* decl, t_combinational_block *_current, t_gather_context *_context)
{
  // gather variable
  t_var_nfo var;
  gatherVarNfo(decl,var);
  addVar(var, _current, _context, (int)decl->getStart()->getLine());
}

// -------------------------------------------------

void Algorithm::gatherInitList(siliceParser::InitListContext* ilist, std::vector<std::string>& _values_str)
{
  for (auto i : ilist->value()) {
    _values_str.push_back(gatherValue(i));
  }
}

// -------------------------------------------------

template<typename D, typename T>
void Algorithm::readInitList(D* decl,T& var)
{
  // read init list
  std::vector<std::string> values_str;
  if (decl->initList() != nullptr) {
    gatherInitList(decl->initList(), values_str);
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
      reportError(decl->getSourceInterval(), (int)decl->getStart()->getLine(), "cannot deduce table size: no size and no initialization given");
    }
    if (decl->UNINITIALIZED() != nullptr) {
      var.do_not_initialize = true;
    } else {
      reportError(decl->getSourceInterval(), (int)decl->getStart()->getLine(), "table has no initializer, use '= uninitialized' if you really don't want to initialize it.");
    }    
  }
  if (var.table_size == 0) { // autosize
    var.table_size = (int)values_str.size();
  } else if (values_str.empty()) {
    // auto init table to 0
  } else if (values_str.size() != var.table_size) {
    reportError(decl->getSourceInterval(), (int)decl->getStart()->getLine(), "incorrect number of values in table initialization");
  }
  var.init_values.resize(var.table_size, "0");
  ForIndex(i, values_str.size()) {
    var.init_values[i] = values_str[i];
  }
}

// -------------------------------------------------

void Algorithm::gatherDeclarationTable(siliceParser::DeclarationTableContext* decl, t_combinational_block *_current, t_gather_context *_context)
{
  t_subroutine_nfo *sub = nullptr;
  if (_current) {
    sub = _current->context.subroutine;
  }
  // check for duplicates
  if (!isIdentifierAvailable(decl->IDENTIFIER()->getText())) {
    reportError(decl->IDENTIFIER()->getSymbol(), (int)decl->getStart()->getLine(), "table '%s': this name is already used by a prior declaration", decl->IDENTIFIER()->getText().c_str());
  }
  // gather table
  t_var_nfo var;  
  if (sub == nullptr) {
    var.name = decl->IDENTIFIER()->getText();
    // block renaming
    std::string base_name = var.name;
    var.name = blockVIOName(base_name, _current);
    _current->context.vio_rewrites.insert(std::make_pair(base_name, var.name));
  } else {
    // subroutine renaming
    var.name = subroutineVIOName(decl->IDENTIFIER()->getText(), sub);
    var.name = blockVIOName(var.name, _current);
    sub->vios.insert(std::make_pair(decl->IDENTIFIER()->getText(), var.name));
    sub->vars.push_back(decl->IDENTIFIER()->getText());
  }
  // type and table size
  splitType(decl->TYPE()->getText(), var.type_nfo);
  if (decl->NUMBER() != nullptr) {
    var.table_size = atoi(decl->NUMBER()->getText().c_str());
    if (var.table_size <= 0) {
      reportError(decl->NUMBER()->getSymbol(), (int)decl->getStart()->getLine(), "table has zero or negative size");
    }
    var.init_values.resize(var.table_size, "0");
  } else {
    var.table_size = 0; // autosize from init
  }
  readInitList(decl, var);
  // insert var
  insertVar(var, _current);
}

// -------------------------------------------------

static int justHigherPow2(int n)
{
  int  p2   = 0;
  bool isp2 = true;
  while (n > 0) {
    if (n > 1 && (n & 1)) {
      isp2 = false;
    }
    ++ p2;
    n = n >> 1;
  }
  return isp2 ? p2-1 : p2;
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

// -------------------------------------------------

void Algorithm::gatherDeclarationMemory(siliceParser::DeclarationMemoryContext* decl, t_combinational_block *_current, t_gather_context *_context)
{
  t_subroutine_nfo *sub = nullptr;
  if (_current) {
    sub = _current->context.subroutine;
  }
  if (sub != nullptr) {
    reportError(decl->getSourceInterval(), (int)decl->getStart()->getLine(), "subroutine '%s': a memory cannot be instanced within a subroutine", sub->name.c_str());
  }
  // check for duplicates
  if (!isIdentifierAvailable(decl->IDENTIFIER()->getText())) {
    reportError(decl->IDENTIFIER()->getSymbol(), (int)decl->getStart()->getLine(), "memory '%s': this name is already used by a prior declaration", decl->IDENTIFIER()->getText().c_str());
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
  } else {
    reportError(decl->getSourceInterval(), (int)decl->getStart()->getLine(), "internal error, memory declaration");
  }
  splitType(decl->TYPE()->getText(), mem.type_nfo);
  if (decl->NUMBER() != nullptr) {
    mem.table_size = atoi(decl->NUMBER()->getText().c_str());
    if (mem.table_size <= 0) {
      reportError(decl->getSourceInterval(), (int)decl->getStart()->getLine(), "memory has zero or negative size");
    }
    mem.init_values.resize(mem.table_size, "0");
  } else {
    mem.table_size = 0; // autosize from init
  }
  readInitList(decl, mem);
  // check
  if (mem.mem_type == BROM && mem.do_not_initialize) {
    reportError(decl->getSourceInterval(), (int)decl->getStart()->getLine(), "a brom has to be initialized: initializer missing, or use a bram instead.");
  }
  // decl. line
  mem.line = (int)decl->getStart()->getLine();
  // create bound variables for access
  std::vector<t_mem_member> members;
  switch (mem.mem_type)     {
  case BRAM:     members = c_BRAMmembers; break;
  case BROM:     members = c_BROMmembers; break;
  case DUALBRAM: members = c_DualPortBRAMmembers; break;
  default: reportError(decl->getSourceInterval(), (int)decl->getStart()->getLine(), "internal error, memory declaration"); break;
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
      auto C = CONFIG.keyValues().find(memid + "_" + m.name + "_width");
      if (C == CONFIG.keyValues().end()) {
        v.type_nfo.width     = mem.type_nfo.width;
      } else if (C->second == "1") {
        v.type_nfo.width     = 1;
      } else if (C->second == "data") {
        v.type_nfo.width     = mem.type_nfo.width;
      }
      // search config for type
      auto T = CONFIG.keyValues().find(memid + "_" + m.name + "_type");
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
    addVar(v, _current, _context, (int)decl->getStart()->getLine());
    if (m.is_input) {
      mem.in_vars.push_back(v.name);
    } else {
      mem.out_vars.push_back(v.name);
    }
    m_VIOBoundToModAlgOutputs[v.name] = WIRE "_mem_" + v.name;
  }
  // clocks
  if (decl->memModifiers() != nullptr) {
    for (auto mod : decl->memModifiers()->memModifier()) {
      if (mod->memClocks() != nullptr) {
        // check clock signal exist
        if (!isVIO(mod->memClocks()->clk0->IDENTIFIER()->getText())
          && mod->memClocks()->clk0->IDENTIFIER()->getText() != ALG_CLOCK
          && mod->memClocks()->clk0->IDENTIFIER()->getText() != m_Clock) {
          reportError(mod->memClocks()->clk0->IDENTIFIER()->getSymbol(),
            (int)mod->memClocks()->clk0->getStart()->getLine(),
            "clock signal '%s' not declared in dual port BRAM", mod->memClocks()->clk0->getText());
        }
        if (!isVIO(mod->memClocks()->clk1->IDENTIFIER()->getText())
          && mod->memClocks()->clk1->IDENTIFIER()->getText() != ALG_CLOCK
          && mod->memClocks()->clk1->IDENTIFIER()->getText() != m_Clock) {
          reportError(mod->memClocks()->clk1->IDENTIFIER()->getSymbol(),
            (int)mod->memClocks()->clk1->getStart()->getLine(),
            "clock signal '%s' not declared in dual port BRAM", mod->memClocks()->clk1->getText());
        }
        // add
        mem.clocks.push_back(mod->memClocks()->clk0->IDENTIFIER()->getText());
        mem.clocks.push_back(mod->memClocks()->clk1->IDENTIFIER()->getText());
      } else if (mod->memNoInputLatch() != nullptr) {
        if (mod->memDelayed() != nullptr) {
          reportError(mod->memNoInputLatch()->getSourceInterval(),
            (int)mod->memNoInputLatch()->getStart()->getLine(),
            "memory cannot use both 'input!' and 'delayed' options");
        }
        mem.no_input_latch = true;
      } else if (mod->memDelayed() != nullptr) {
        if (mod->memNoInputLatch() != nullptr) {
          reportError(mod->memDelayed()->getSourceInterval(),
            (int)mod->memDelayed()->getStart()->getLine(),
            "memory cannot use both 'input!' and 'delayed' options");
        }
        mem.delayed = true;
      }
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
  siliceParser::ModalgBindingListContext *bindings,
  std::vector<t_binding_nfo>& _vec_bindings,
  bool& _autobind) const
{
  if (bindings == nullptr) return;
  while (bindings != nullptr) {
    if (bindings->modalgBinding() != nullptr) {
      if (bindings->modalgBinding()->AUTO() != nullptr) {
        _autobind = true;
      } else {
        // check if this is a group binding
        if (bindings->modalgBinding()->BDEFINE() != nullptr || bindings->modalgBinding()->BDEFINEDBL() != nullptr) {
          auto G = m_VIOGroups.find(bindings->modalgBinding()->right->getText());
          if (G != m_VIOGroups.end()) {
            // verify right is an identifier
            if (bindings->modalgBinding()->right->IDENTIFIER() == nullptr) {
              reportError(
                bindings->modalgBinding()->getSourceInterval(),
                (int)bindings->modalgBinding()->right->getStart()->getLine(), 
                "expecting an identifier on the right side of a group binding");
            }
            // unfold all bindings, select direction automatically
            // NOTE: some members may not be used, these are excluded during auto-binding
            for (auto v : getGroupMembers(G->second)) {
              string member = v;
              t_binding_nfo nfo;
              nfo.left  = bindings->modalgBinding()->left->getText() + "_" + member;
              nfo.right_identifier = bindings->modalgBinding()->right->IDENTIFIER()->getText() + "_" + member;
              nfo.line  = (int)bindings->modalgBinding()->getStart()->getLine();
              nfo.dir   = (bindings->modalgBinding()->BDEFINE() != nullptr) ? e_Auto : e_AutoQ;
              _vec_bindings.push_back(nfo);
            }
            // skip to next
            bindings = bindings->modalgBindingList();
            continue;
          }
        }
        t_binding_nfo nfo;
        nfo.left = bindings->modalgBinding()->left->getText();
        if (bindings->modalgBinding()->right->IDENTIFIER() != nullptr) {
          nfo.right_identifier = bindings->modalgBinding()->right->IDENTIFIER()->getText();
        } else {
          sl_assert(bindings->modalgBinding()->right->ioAccess() != nullptr);
          nfo.right_access = bindings->modalgBinding()->right->ioAccess();
        }
        nfo.line = (int)bindings->modalgBinding()->getStart()->getLine();
        if (bindings->modalgBinding()->LDEFINE() != nullptr) {
          nfo.dir = e_Left;
        } else if (bindings->modalgBinding()->LDEFINEDBL() != nullptr) {
          nfo.dir = e_LeftQ;
        } else if (bindings->modalgBinding()->RDEFINE() != nullptr) {
          nfo.dir = e_Right;
        } else if (bindings->modalgBinding()->BDEFINE() != nullptr) {
          nfo.dir = e_BiDir;
        } else {
          reportError(
            bindings->modalgBinding()->getSourceInterval(),
            (int)bindings->modalgBinding()->right->getStart()->getLine(),
            "this binding operator can only be used on io groups");
        }
        _vec_bindings.push_back(nfo);
      }
    }
    bindings = bindings->modalgBindingList();
  }
}

// -------------------------------------------------

void Algorithm::gatherDeclarationGroup(siliceParser::DeclarationGrpModAlgContext* grp, t_combinational_block *_current, t_gather_context *_context)
{
  // check for duplicates
  if (!isIdentifierAvailable(grp->name->getText())) {
    reportError(grp->getSourceInterval(), (int)grp->getStart()->getLine(), "group '%s': this name is already used by a prior declaration", grp->name->getText().c_str());
  }
  // gather
  auto G = m_KnownGroups.find(grp->modalg->getText());
  if (G != m_KnownGroups.end()) {
    m_VIOGroups.insert(make_pair(grp->name->getText(), G->second));
    for (auto v : G->second->varList()->var()) {
      // create group variables
      t_var_nfo vnfo;
      gatherVarNfo(v->declarationVar(), vnfo);
      vnfo.name = grp->name->getText() + "_" + vnfo.name;
      addVar(vnfo, _current, _context, (int)grp->getStart()->getLine());
    }
  } else {
    reportError(grp->getSourceInterval(), (int)grp->getStart()->getLine(), "unkown group '%s'", grp->modalg->getText().c_str());
  }
}

// -------------------------------------------------

void Algorithm::gatherDeclarationAlgo(siliceParser::DeclarationGrpModAlgContext* alg, t_combinational_block *_current, t_gather_context *_context)
{  
  t_subroutine_nfo *sub = nullptr;
  if (_current) {
    sub = _current->context.subroutine;
  }
  if (sub != nullptr) {
    reportError(alg->getSourceInterval(), (int)alg->name->getLine(), "subroutine '%s': algorithms cannot be instanced within subroutines", sub->name.c_str()); 
  }
  // check for duplicates
  if (!isIdentifierAvailable(alg->name->getText())) {
    reportError(alg->getSourceInterval(), (int)alg->getStart()->getLine(), "algorithm instance '%s': this name is already used by a prior declaration", alg->name->getText().c_str());
  }
  // gather
  t_algo_nfo nfo;
  nfo.algo_name      = alg->modalg->getText();
  nfo.instance_name  = alg->name->getText();
  nfo.instance_clock = m_Clock;
  nfo.instance_reset = m_Reset;
  if (alg->algModifiers() != nullptr) {
    for (auto m : alg->algModifiers()->algModifier()) {
      if (m->sclock() != nullptr) {
        nfo.instance_clock = m->sclock()->IDENTIFIER()->getText();
      }
      if (m->sreset() != nullptr) {
        nfo.instance_reset = m->sreset()->IDENTIFIER()->getText();
      }
      if (m->sautorun() != nullptr) {
        reportError(m->sautorun()->AUTORUN()->getSymbol(), (int)m->sautorun()->getStart()->getLine(), "autorun not allowed when instantiating algorithms" );
      }
    }
  }
  nfo.instance_prefix = "_" + alg->name->getText();
  nfo.instance_line   = (int)alg->getStart()->getLine();
  if (m_InstancedAlgorithms.find(nfo.instance_name) != m_InstancedAlgorithms.end()) {
    reportError(alg->name, (int)alg->name->getLine(), "an algorithm was already instantiated with the same name" );
  }
  nfo.autobind = false;
  getBindings(alg->modalgBindingList(), nfo.bindings, nfo.autobind);
  m_InstancedAlgorithms[nfo.instance_name] = nfo;
  m_InstancedAlgorithmsInDeclOrder.push_back(nfo.instance_name);
}

// -------------------------------------------------

void Algorithm::gatherDeclarationModule(siliceParser::DeclarationGrpModAlgContext* mod, t_combinational_block *_current, t_gather_context *_context)
{
  t_subroutine_nfo *sub = nullptr;
  if (_current) {
    sub = _current->context.subroutine;
  }
  if (sub != nullptr) {
    reportError(mod->name,(int)mod->name->getLine(),"subroutine '%s': modules cannot be instanced within subroutines", sub->name.c_str());
  }
  // check for duplicates
  if (!isIdentifierAvailable(mod->name->getText())) {
    reportError(mod->getSourceInterval(), (int)mod->getStart()->getLine(), "module instance '%s': this name is already used by a prior declaration", mod->name->getText().c_str());
  }
  // gather
  t_module_nfo nfo;
  nfo.module_name = mod->modalg->getText();
  nfo.instance_name = mod->name->getText();
  nfo.instance_prefix = "_" + mod->name->getText();
  nfo.instance_line = (int)mod->getStart()->getLine();
  if (m_InstancedModules.find(nfo.instance_name) != m_InstancedModules.end()) {
    reportError(mod->name,(int)mod->name->getLine(),"a module was already instantiated with the same name");
  }
  nfo.autobind = false;
  getBindings(mod->modalgBindingList(), nfo.bindings, nfo.autobind);
  m_InstancedModules[nfo.instance_name] = nfo;
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

std::string Algorithm::rewriteIdentifier(
  std::string prefix, std::string var,
  const t_combinational_block_context *bctx,
  size_t line,
  std::string ff, bool read_access,
  const t_vio_dependencies& dependencies,
  t_vio_ff_usage &_ff_usage, e_FFUsage ff_Force) const
{
  sl_assert(!(!read_access && ff == FF_Q));
  if (var == ALG_RESET || var == ALG_CLOCK) {
    return var;
  } else if (var == m_Reset) { // cannot be ALG_RESET
    if (m_VIOBoundToModAlgOutputs.find(var) == m_VIOBoundToModAlgOutputs.end()) {
      reportError(nullptr, (int)line, "custom reset signal has to be bound to a module output");
    }
    return m_VIOBoundToModAlgOutputs.at(var);
  } else if (var == m_Clock) { // cannot be ALG_CLOCK
    if (m_VIOBoundToModAlgOutputs.find(var) == m_VIOBoundToModAlgOutputs.end()) {
      reportError(nullptr, (int)line, "custom clock signal has to be bound to a module output");
    }
    return m_VIOBoundToModAlgOutputs.at(var);
  } else {
    // vio? translate
    var = translateVIOName(var, bctx);
    // keep going
    if (isInput(var)) {
      return ALG_INPUT + prefix + var;
    } else if (isInOut(var)) {
      reportError(nullptr, (int)line, "cannot use inouts directly in expressions");
      //return ALG_INOUT + prefix + var;
    } else if (isOutput(var)) {
      auto usage = m_Outputs.at(m_OutputNames.at(var)).usage;
      if (usage == e_Temporary) {
        // temporary
        return FF_TMP + prefix + var;
      } else if (usage == e_FlipFlop) {
        // flip-flop
        if (ff == FF_Q) {
          if (dependencies.dependencies.count(var) > 0) {
            updateFFUsage((e_FFUsage)((int)e_D | ff_Force), read_access, _ff_usage.ff_usage[var]);
            return FF_D + prefix + var;
          } else {
            updateFFUsage((e_FFUsage)((int)e_Q | ff_Force), read_access, _ff_usage.ff_usage[var]);
          }
        } else {
          sl_assert(ff == FF_D);
          updateFFUsage((e_FFUsage)((int)e_D | ff_Force), read_access, _ff_usage.ff_usage[var]);
        }
        return ff + prefix + var;
      } else if (usage == e_Bound) {
        // bound
        return m_VIOBoundToModAlgOutputs.at(var);
      } else {
        reportError(nullptr, (int)line, "internal error [%s, %d]", __FILE__, __LINE__);
      }
    } else {
      auto V = m_VarNames.find(var);
      if (V == m_VarNames.end()) {
        reportError(nullptr, (int)line, "variable '%s' was never declared", var.c_str());
      }
      if (m_Vars.at(V->second).usage == e_Bound) {
        // bound to an output?
        auto Bo = m_VIOBoundToModAlgOutputs.find(var);
        if (Bo != m_VIOBoundToModAlgOutputs.end()) {
          return Bo->second;
        }
        reportError(nullptr, (int)line, "internal error [%s, %d]", __FILE__, __LINE__);
      } else {
        if (m_Vars.at(V->second).usage == e_Temporary) {
          // temporary
          return FF_TMP + prefix + var;
        } else if (m_Vars.at(V->second).usage == e_Const) {
          // const
          return FF_CST + prefix + var;
        } else if (m_Vars.at(V->second).usage == e_Wire) {
          // wire
          return WIRE + prefix + var;
        } else {
          // flip-flop
          if (ff == FF_Q) {
            if (dependencies.dependencies.count(var) > 0) {
              updateFFUsage((e_FFUsage)((int)e_D | ff_Force), read_access, _ff_usage.ff_usage[var]);
              return FF_D + prefix + var;
            } else {
              updateFFUsage((e_FFUsage)((int)e_Q | ff_Force), read_access, _ff_usage.ff_usage[var]);
            }
          } else {
            sl_assert(ff == FF_D);
            updateFFUsage((e_FFUsage)((int)e_D | ff_Force), read_access, _ff_usage.ff_usage[var]);
          }
          return ff + prefix + var;
        }
      }
    }
  }
  reportError(nullptr, (int)line, "internal error [%s, %d]", __FILE__, __LINE__);
  return "";
}

// -------------------------------------------------

std::string Algorithm::rewriteExpression(
  std::string prefix, antlr4::tree::ParseTree *expr, 
  int __id, const t_combinational_block_context *bctx, 
  std::string ff, bool read_access,
  const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const
{
  std::string result;
  if (expr->children.empty()) {
    auto term = dynamic_cast<antlr4::tree::TerminalNode*>(expr);
    if (term) {
      if (term->getSymbol()->getType() == siliceParser::IDENTIFIER) {
        return rewriteIdentifier(prefix, expr->getText(), bctx, term->getSymbol()->getLine(), ff, read_access, dependencies, _ff_usage);
      } else if (term->getSymbol()->getType() == siliceParser::CONSTANT) {
        return rewriteConstant(expr->getText());
      } else if (term->getSymbol()->getType() == siliceParser::REPEATID) {
        if (__id == -1) {
          reportError(term->getSymbol(), (int)term->getSymbol()->getLine(), "__id used outside of repeat block");
        }
        return std::to_string(__id);
      } else if (term->getSymbol()->getType() == siliceParser::TOUNSIGNED) {
        return "$unsigned";
      } else if (term->getSymbol()->getType() == siliceParser::TOSIGNED) {
        return "$signed";
      } else {
        return expr->getText();
      }
    } else {
      return expr->getText();
    }
  } else {
    auto access = dynamic_cast<siliceParser::AccessContext*>(expr);
    if (access) {
      std::ostringstream ostr;
      writeAccess(prefix, ostr, false, access, __id, bctx, ff, dependencies, _ff_usage);
      result = result + ostr.str();
    } else {
      // recurse
      for (auto c : expr->children) {
        result = result + rewriteExpression(prefix, c, __id, bctx, ff, read_access, dependencies, _ff_usage);
      }
    }
  }
  return result;
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
  t_combinational_block *newblock = addBlock(generateBlockName(), _current, nullptr, (int)block->getStart()->getLine());
  _current->next(newblock);
  // gather declarations in new block
  gatherDeclarationList(block->declarationList(), newblock, _context, true);
  // gather instructions in new block
  t_combinational_block *after     = gather(block->instructionList(), newblock, _context);
  // produce next block
  t_combinational_block *nextblock = addBlock(generateBlockName(), _current, nullptr, (int)block->getStart()->getLine());
  after->next(nextblock);
  return nextblock;
}

// -------------------------------------------------

Algorithm::t_combinational_block *Algorithm::splitOrContinueBlock(siliceParser::InstructionListContext* ilist, t_combinational_block *_current, t_gather_context *_context)
{
  if (ilist->state() != nullptr) {
    // start a new block
    std::string name = "++";
    if (ilist->state()->state_name != nullptr) {
      name = ilist->state()->state_name->getText();
    }
    bool no_skip   = false;
    if (name == "++") {
      name      = generateBlockName();
      no_skip   = true;
    }
    t_combinational_block *block = addBlock(name, _current, nullptr, (int)ilist->state()->getStart()->getLine());
    block->is_state     = true;    // block explicitely required to be a state (may become a sub-state)
    block->could_be_sub = false;   // TODO command line option // no_skip; // could become a sub-state
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
    reportError(brk->BREAK()->getSymbol(), (int)brk->getStart()->getLine(),"cannot break outside of a loop");
  }
  _current->next(_context->break_to);
  _context->break_to->is_state = true;
  // start a new block after the break
  t_combinational_block *block = addBlock(generateBlockName(), _current);
  // return block
  return block;
}

// -------------------------------------------------

Algorithm::t_combinational_block *Algorithm::gatherWhile(siliceParser::WhileLoopContext* loop, t_combinational_block *_current, t_gather_context *_context)
{
  // while header block
  t_combinational_block *while_header = addBlock("__while" + generateBlockName(), _current);
  _current->next(while_header);
  // iteration block
  t_combinational_block *iter = addBlock(generateBlockName(), _current);
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
  while_header->while_loop(t_instr_nfo(loop->expression_0(), _context->__id), iter, after);
  // set states
  while_header->is_state = true; // header has to be a state
  after->is_state = true; // after has to be a state
  return after;
}

// -------------------------------------------------

void Algorithm::gatherDeclaration(siliceParser::DeclarationContext *decl, t_combinational_block *_current, t_gather_context *_context, bool var_table_only)
{
  auto declvar   = dynamic_cast<siliceParser::DeclarationVarContext*>(decl->declarationVar());
  auto declwire  = dynamic_cast<siliceParser::DeclarationWireContext *>(decl->declarationWire());
  auto decltbl   = dynamic_cast<siliceParser::DeclarationTableContext*>(decl->declarationTable());
  auto grpmodalg = dynamic_cast<siliceParser::DeclarationGrpModAlgContext*>(decl->declarationGrpModAlg());
  auto declmem   = dynamic_cast<siliceParser::DeclarationMemoryContext*>(decl->declarationMemory());
  if (var_table_only) {
    if (declmem) {
      reportError(declmem->IDENTIFIER()->getSymbol(), (int)decl->getStart()->getLine(),
        "cannot declare a memory here");
    }
    if (grpmodalg) {
      reportError(grpmodalg->getSourceInterval(), (int)decl->getStart()->getLine(),
        "cannot declare groups, nor intantiate modules or algorithms here");
    }
  }
  if (declvar)        { gatherDeclarationVar(declvar, _current, _context); }
  else if (declwire)  { gatherDeclarationWire(declwire, _current, _context); }
  else if (decltbl)   { gatherDeclarationTable(decltbl, _current, _context); }
  else if (declmem)   { gatherDeclarationMemory(declmem, _current, _context); }
  else if (grpmodalg) {
    std::string name = grpmodalg->modalg->getText();
    if (m_KnownGroups.find(name) != m_KnownGroups.end()) {
      gatherDeclarationGroup(grpmodalg, _current, _context);
    } else if (m_KnownModules.find(name) != m_KnownModules.end()) {
      gatherDeclarationModule(grpmodalg, _current, _context);
    } else {
      gatherDeclarationAlgo(grpmodalg, _current, _context);
    }
  }
}

//-------------------------------------------------

int Algorithm::gatherDeclarationList(siliceParser::DeclarationListContext* decllist, t_combinational_block *_current, t_gather_context* _context,bool var_table_only)
{
  if (decllist == nullptr) {
    return 0;
  }
  int num = 0;
  siliceParser::DeclarationListContext *cur_decllist = decllist;
  while (cur_decllist->declaration() != nullptr) {
    siliceParser::DeclarationContext* decl = cur_decllist->declaration();
    gatherDeclaration(decl, _current, _context, var_table_only);
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
  if (m_InstancedAlgorithms.count(name) > 0) {
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

Algorithm::t_combinational_block *Algorithm::gatherSubroutine(siliceParser::SubroutineContext* sub, t_combinational_block *_current, t_gather_context *_context)
{
  if (_current->context.subroutine != nullptr) {
    reportError(sub->IDENTIFIER()->getSymbol(), (int)sub->getStart()->getLine(), "subroutine '%s': cannot declare a subroutine in another", sub->IDENTIFIER()->getText().c_str());
  }
  t_subroutine_nfo *nfo = new t_subroutine_nfo;
  // subroutine name
  nfo->name = sub->IDENTIFIER()->getText();
  // check for duplicates
  if (!isIdentifierAvailable(nfo->name)) {
    reportError(sub->IDENTIFIER()->getSymbol(), (int)sub->getStart()->getLine(),"subroutine '%s': this name is already used by a prior declaration", nfo->name.c_str());
  }
  // subroutine block
  t_combinational_block *subb = addBlock(SUB_ENTRY_BLOCK + nfo->name, _current, nullptr, (int)sub->getStart()->getLine());
  subb->context.subroutine    = nfo;
  nfo->top_block              = subb;
  // subroutine local declarations
  int numdecl = gatherDeclarationList(sub->declarationList(), subb, _context, true);
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
      // find subroutine being called
      auto S = m_Subroutines.find(P->IDENTIFIER()->getText());
      if (S == m_Subroutines.end()) {
        reportError(P->IDENTIFIER()->getSymbol(), (int)P->getStart()->getLine(),  
          "cannot find subroutine '%s' declared called by subroutine '%s'",
          P->IDENTIFIER()->getText().c_str(), nfo->name.c_str());
      }
      // add all inputs/outputs
      for (auto ins : S->second->inputs) {
        nfo->allowed_writes.insert(S->second->vios.at(ins));
      }
      for (auto outs : S->second->outputs) {
        nfo->allowed_reads.insert(S->second->vios.at(outs));
      }
    }
    // input or output?
    if (P->input() != nullptr || P->output() != nullptr) {
      std::string in_or_out;
      std::string ioname;
      std::string strtype;
      int tbl_size = 0;
      if (P->input() != nullptr) {
        in_or_out = "i";
        ioname = P->input()->IDENTIFIER()->getText();
        strtype = P->input()->TYPE()->getText();
        if (P->input()->NUMBER() != nullptr) {
          reportError(P->getSourceInterval(), (int)P->getStart()->getLine(),
            "subroutine '%s' input '%s', tables as input are not yet supported",
            nfo->name.c_str(), ioname.c_str());
          tbl_size = atoi(P->input()->NUMBER()->getText().c_str());
        }
        nfo->inputs.push_back(ioname);
      } else {
        in_or_out = "o";
        ioname = P->output()->IDENTIFIER()->getText();
        strtype = P->output()->TYPE()->getText();
        if (P->output()->NUMBER() != nullptr) {
          reportError(P->getSourceInterval(), (int)P->getStart()->getLine(),
            "subroutine '%s' output '%s', tables as output are not yet supported",
            nfo->name.c_str(), ioname.c_str());
          tbl_size = atoi(P->output()->NUMBER()->getText().c_str());
        }
        nfo->outputs.push_back(ioname);
      }
      // check for name collisions
      if (m_InputNames.count(ioname) > 0
        || m_OutputNames.count(ioname) > 0
        || m_VarNames.count(ioname) > 0
        || ioname == m_Clock || ioname == m_Reset) {
        reportError(P->getSourceInterval(), (int)P->getStart()->getLine(),
          "subroutine '%s' input/output '%s' is using the same name as a host VIO, clock or reset",
          nfo->name.c_str(), ioname.c_str());
      }
      // insert variable in host for each input/output
      t_var_nfo var;
      var.name = in_or_out + "_" + nfo->name + "_" + ioname;
      var.table_size = tbl_size;
      splitType(strtype, var.type_nfo);
      var.init_values.resize(max(var.table_size, 1), "0");
      // insert var
      insertVar(var, _current, true /*no init*/);
      // record in subroutine
      nfo->vios.insert(std::make_pair(ioname, var.name));
      // add to allowed read/write list
      if (P->input() != nullptr) {
        nfo->allowed_reads .insert(var.name);
      } else {
        nfo->allowed_writes.insert(var.name);
        nfo->allowed_reads .insert(var.name);
      }
      nfo->top_block->declared_vios.insert(var.name);
    }
  }
  // parse the subroutine
  t_combinational_block *sub_last = gather(sub->instructionList(), subb, _context);
  // add return from last
  sub_last->return_from();
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

Algorithm::t_combinational_block *Algorithm::gatherPipeline(siliceParser::PipelineContext* pip, t_combinational_block *_current, t_gather_context *_context)
{
  if (_current->context.pipeline != nullptr) {
    reportError(pip->getSourceInterval(), (int)pip->getStart()->getLine(), "pipelines cannot be nested");
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
    t_combinational_block_context ctx  = { _current->context.subroutine, snfo, _current->context.parent_scope };
    t_combinational_block *stage_start = addBlock("__stage_" + generateBlockName(), _current, &ctx, (int)b->getStart()->getLine());
    t_combinational_block *stage_end   = gather(b, stage_start, _context);
    // check this is a combinational chain
    if (!isStateLessGraph(stage_start)) {
      reportError(nullptr,(int)b->getStart()->getLine(),"pipeline stages have to be combinational only");
    }
    // check VIO access
    // -> gather read/written for block
    std::unordered_set<std::string> read, written;
    determineVIOAccess(b, m_VarNames,    &_current->context, read, written);
    determineVIOAccess(b, m_OutputNames, &_current->context, read, written);
    determineVIOAccess(b, m_InputNames,  &_current->context, read, written);
    // -> check for anything wrong: no stage should *read* a value *written* by a later stage
    for (auto w : written) {
      if (read_at.count(w) > 0) {
        reportError(nullptr,(int)b->getStart()->getLine(),"pipeline inconsistency.\n       stage reads a value written by a later stage (write on '%s')",w.c_str());
      }
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
  // report on read variables
  for (auto r : read_at) {
    // trickling?
    bool trickling = false;
    if (r.second.size() > 1) {
      trickling = true;
    } else {
      sl_assert(!r.second.empty());
      int read_stage = r.second[0]; // only one if here
      // search max write
      // (there can be multiple successive writes ... but no read in between
      //  otherwise the constraint no stage should *read* a value *written* by a later stage
      //  is violated)
      int last_write = -1;
      if (written_at.count(r.first)) {
        // has been written
        for (auto ws : written_at[r.first]) {
          if (ws < read_stage) { // ignore write at same stage
            last_write = max(last_write, ws);
          }
        }
      }
      if ( last_write == -1 // not written in stages before, have to assume it is before pipeline
                            // TODO: this ignores the case of a read masked by a write before in same stage (temp)
        || read_stage - last_write > 1) {
        trickling = true;
      }
    }
    if (trickling) {
      trickling_vios.insert(r.first);
    }
    for (auto s : r.second) {
      std::cerr << "vio " << r.first << " read at stage " << s << nxl;
    }
  }
  // report on written variables
  for (auto w : written_at) {
    for (auto s : w.second) {
      std::cerr << "vio " << w.first << " written at stage " << s;
      std::cerr << nxl;
    }
  }
  // create trickling variables
  for (auto tv : trickling_vios) {
    // the 'deepest' stage it is read
    int last_read = 0;
    for (auto rs : read_at[tv]) {
      last_read = max(last_read, rs);
    }
    // the 'deepest' stage it is written
    int last_write = 0;
    if (written_at.count(tv)) {
      for (auto ws : written_at[tv]) {
        last_write = max(last_write, ws);
      }
    }
    // register in pipeline info
    nfo->trickling_vios.insert(std::make_pair(tv, v2i(last_write,last_read)));
    // report
    std::cerr << tv << " trickling from " << last_write << " to " << last_read << nxl;
    // info from source var
    auto tws = determineVIOTypeWidthAndTableSize(&_current->context, tv, (int)pip->getStart()->getLine());
    // generate one flip-flop per stage
    ForRange(s, last_write+1, last_read) {
      // -> add variable
      t_var_nfo var;
      var.name = tricklingVIOName(tv,nfo,s);
      var.type_nfo   = get<0>(tws);
      var.table_size = get<1>(tws);
      var.init_values.resize(var.table_size > 0 ? var.table_size : 1, "0");
      var.access = e_InternalFlipFlop;
      insertVar(var, _current, true /*no init*/);
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
  t_combinational_block* after = addBlock(generateBlockName(), _current);
  // return block after jump
  return after;
}

// -------------------------------------------------

Algorithm::t_combinational_block *Algorithm::gatherCall(siliceParser::CallContext* call, t_combinational_block *_current, t_gather_context *_context)
{
  // start a new block just after the call
  t_combinational_block* after = addBlock(generateBlockName(), _current);
  // has to be a state to return to
  after->is_state = true;
  // find the destination
  std::string name = call->IDENTIFIER()->getText();
  auto B = m_State2Block.find(name);
  if (B == m_State2Block.end()) {
    // forward reference
    _current->goto_and_return_to(nullptr, after);
    t_forward_jump j;
    j.from = _current;
    j.jump = call;
    m_JumpForwardRefs[name].push_back(j);
  } else {
    // current goes there and return on next
    _current->goto_and_return_to(B->second, after);
    B->second->is_state = true; // destination has to be a state
  }
  // return block after call
  return after;
}

// -------------------------------------------------

Algorithm::t_combinational_block* Algorithm::gatherReturnFrom(siliceParser::ReturnFromContext* ret, t_combinational_block* _current, t_gather_context* _context)
{
  // add return at end of current
  _current->return_from();
  // start a new block
  t_combinational_block* block = addBlock(generateBlockName(), _current);
  return block;
}

// -------------------------------------------------

Algorithm::t_combinational_block* Algorithm::gatherSyncExec(siliceParser::SyncExecContext* sync, t_combinational_block* _current, t_gather_context* _context)
{
  if (_context->__id != -1) {
    reportError(sync->LARROW()->getSymbol(), (int)sync->getStart()->getLine(),"repeat blocks cannot wait for a parallel execution");
  }
  // add sync as instruction, will perform the call
  _current->instructions.push_back(t_instr_nfo(sync, _context->__id));
  // are we calling a subroutine?
  auto S = m_Subroutines.find(sync->joinExec()->IDENTIFIER()->getText());
  if (S != m_Subroutines.end()) {
    // yes! create a new block, call subroutine
    t_combinational_block* after = addBlock(generateBlockName(), _current);
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
    reportError(join->LARROW()->getSymbol(), (int)join->getStart()->getLine(), "repeat blocks cannot wait a parallel execution");
  }
  // are we calling a subroutine?
  auto S = m_Subroutines.find(join->IDENTIFIER()->getText());
  if (S == m_Subroutines.end()) { // no, waiting for algorithm
    // block for the wait
    t_combinational_block* waiting_block = addBlock(generateBlockName(), _current);
    waiting_block->is_state = true; // state for waiting
    // enter wait after current
    _current->next(waiting_block);
    // block for after the wait
    t_combinational_block* next_block = addBlock(generateBlockName(), _current);
    next_block->is_state = true; // state to goto after the wait
    // ask current block to wait the algorithm termination
    waiting_block->wait((int)join->getStart()->getLine(), join->IDENTIFIER()->getText(), waiting_block, next_block);
    // first instruction in next block will read result
    next_block->instructions.push_back(t_instr_nfo(join, _context->__id));
    // use this next block now
    return next_block;
  } else {
    // subroutine, simply readback results
    _current->instructions.push_back(t_instr_nfo(join, _context->__id));
    return _current;
  }
}

// -------------------------------------------------

bool Algorithm::isStateLessGraph(t_combinational_block *head) const
{
  std::queue< t_combinational_block* > q;
  q.push(head);
  while (!q.empty()) {
    auto cur = q.front();
    q.pop();
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
      q.push(c);
    }
  }
  return true;
}

// -------------------------------------------------

void Algorithm::findNonCombinationalLeaves(const t_combinational_block *head, std::set<t_combinational_block*>& _leaves) const
{
  std::queue< t_combinational_block* >  q;
  std::vector< t_combinational_block* > children;
  head->getChildren(children);
  for (auto c : children) {
    q.push(c);
  }
  while (!q.empty()) {
    auto cur = q.front();
    q.pop();
    // test
    if (cur == nullptr) { // tags a forward ref (jump), not stateless
      _leaves.insert(cur);
    } else if (cur->is_state || cur->is_sub_state) {
      _leaves.insert(cur);
    } else {
      // recurse
      children.clear();
      cur->getChildren(children);
      for (auto c : children) {
        q.push(c);
      }
    }
  }
}

// -------------------------------------------------

Algorithm::t_combinational_block* Algorithm::gatherCircuitryInst(siliceParser::CircuitryInstContext* ci, t_combinational_block* _current, t_gather_context* _context)
{
  // find circuitry in known circuitries
  std::string name = ci->IDENTIFIER()->getText();
  auto C = m_KnownCircuitries.find(name);
  if (C == m_KnownCircuitries.end()) {
    reportError(ci->IDENTIFIER()->getSymbol(), (int)ci->getStart()->getLine(), "circuitry not yet declared");
  }
  // instantiate in a new block
  t_combinational_block* cblock = addBlock(generateBlockName() + "_" + name, _current);
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
        reportError(C->second->IDENTIFIER()->getSymbol(), (int)C->second->getStart()->getLine(),"a circuitry output is combinational by default");
      }
      outs.push_back(io->IDENTIFIER()->getText());
    } else if (io->is_inout != nullptr) {
      ins.push_back(io->IDENTIFIER()->getText());
      outs.push_back(io->IDENTIFIER()->getText());
    } else {
      reportError(C->second->IDENTIFIER()->getSymbol(), (int)C->second->getStart()->getLine(), "internal error");
    }
  }
  // -> get identifiers
  vector<string> ins_idents, outs_idents;
  getIdentifiers(ci->ins, ins_idents, nullptr);
  getIdentifiers(ci->outs, outs_idents, nullptr);
  // -> checks
  if (ins.size() != ins_idents.size()) {
    reportError(ci->IDENTIFIER()->getSymbol(), (int)ci->getStart()->getLine(), "Incorrect number of inputs in circuitry instanciation (circuitry '%s')", name.c_str());
  }
  if (outs.size() != outs_idents.size()) {
    reportError(ci->IDENTIFIER()->getSymbol(), (int)ci->getStart()->getLine(), "Incorrect number of outputs in circuitry instanciation (circuitry '%s')", name.c_str());
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
  t_combinational_block* after = addBlock(generateBlockName(), _current);
  cblock_after->next(after);
  return after;
}

// -------------------------------------------------

Algorithm::t_combinational_block *Algorithm::gatherIfElse(siliceParser::IfThenElseContext* ifelse, t_combinational_block *_current, t_gather_context *_context)
{
  t_combinational_block *if_block = addBlock(generateBlockName(), _current);
  t_combinational_block *else_block = addBlock(generateBlockName(), _current);
  // parse the blocks
  t_combinational_block *if_block_after = gather(ifelse->if_block, if_block, _context);
  t_combinational_block *else_block_after = gather(ifelse->else_block, else_block, _context);
  // create a block for after the if-then-else
  t_combinational_block *after = addBlock(generateBlockName(), _current);
  if_block_after->next(after);
  else_block_after->next(after);
  // add if_then_else to current
  _current->if_then_else(t_instr_nfo(ifelse->expression_0(), _context->__id), if_block, else_block, after);
  // checks whether after has to be a state
  after->is_state = !isStateLessGraph(if_block) || !isStateLessGraph(else_block);
  return after;
}

// -------------------------------------------------

Algorithm::t_combinational_block *Algorithm::gatherIfThen(siliceParser::IfThenContext* ifthen, t_combinational_block *_current, t_gather_context *_context)
{
  t_combinational_block *if_block = addBlock(generateBlockName(), _current);
  t_combinational_block *else_block = addBlock(generateBlockName(), _current);
  // parse the blocks
  t_combinational_block *if_block_after = gather(ifthen->if_block, if_block, _context);
  // create a block for after the if-then-else
  t_combinational_block *after = addBlock(generateBlockName(), _current);
  if_block_after->next(after);
  else_block->next(after);
  // add if_then_else to current
  _current->if_then_else(t_instr_nfo(ifthen->expression_0(), _context->__id), if_block, else_block, after);
  // checks whether after has to be a state
  after->is_state = !isStateLessGraph(if_block);
  return after;
}

// -------------------------------------------------

Algorithm::t_combinational_block* Algorithm::gatherSwitchCase(siliceParser::SwitchCaseContext* switchCase, t_combinational_block* _current, t_gather_context* _context)
{
  // create a block for after the switch-case
  t_combinational_block* after = addBlock(generateBlockName(), _current);
  // create a block per case statement
  std::vector<std::pair<std::string, t_combinational_block*> > case_blocks;
  for (auto cb : switchCase->caseBlock()) {
    t_combinational_block* case_block = addBlock(generateBlockName() + "_case", _current);
    std::string            value = "default";
    if (cb->case_value != nullptr) {
      value = gatherValue(cb->case_value);
    }
    case_blocks.push_back(std::make_pair(value, case_block));
    t_combinational_block* case_block_after = gather(cb->case_block, case_block, _context);
    case_block_after->next(after);
  }
  // add switch-case to current
  _current->switch_case(t_instr_nfo(switchCase->expression_0(), _context->__id), case_blocks, after);
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
    reportError(repeat->REPEATCNT()->getSymbol(), (int)repeat->getStart()->getLine(), "repeat blocks cannot be nested");
  } else {
    std::string rcnt = repeat->REPEATCNT()->getText();
    int num = atoi(rcnt.substr(0, rcnt.length() - 1).c_str());
    if (num <= 0) {
      reportError(repeat->REPEATCNT()->getSymbol(), (int)repeat->getStart()->getLine(), "repeat count has to be greater than zero");
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
      always->instructions.push_back(t_instr_nfo(alw, -1));
      // check for double flip-flop
      if (alw->ALWSASSIGNDBL() != nullptr) {
        // insert temporary variable
        t_var_nfo var;
        var.name = "delayed_" + std::to_string(alw->getStart()->getLine()) + "_" + std::to_string(alw->getStart()->getCharPositionInLine());
        t_type_nfo typenfo = determineAccessTypeAndWidth(nullptr, alw->access(), alw->IDENTIFIER());
        var.table_size     = 0;
        var.type_nfo       = typenfo;
        var.init_values.push_back("0");
        insertVar(var, always, true /*no init*/);
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
    // now verify all permissions are granted
    for (auto R : read) {
      if (_current->context.subroutine->allowed_reads.count(R) == 0) {
        reportError(node->getSourceInterval(), -1, "variable '%s' is read by subroutine '%s' without explicit permission", R.c_str(), _current->context.subroutine->name.c_str());
      }
    }
    for (auto W : written) {
      if (_current->context.subroutine->allowed_writes.count(W) == 0) {
        reportError(node->getSourceInterval(), -1, "variable '%s' is written by subroutine '%s' without explicit permission", W.c_str(), _current->context.subroutine->name.c_str());
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
      reportError(node->getSourceInterval(), -1, "variable '%s' is either unknown or out of scope", V.c_str());
    }
  }
}

// -------------------------------------------------

void Algorithm::gatherInputNfo(siliceParser::InputContext* input,t_inout_nfo& _io)
{
  _io.name = input->IDENTIFIER()->getText();
  _io.table_size = 0;
  splitType(input->TYPE()->getText(), _io.type_nfo);
  if (input->NUMBER() != nullptr) {
    reportError(input->getSourceInterval(), -1, "input '%s': tables as input are not yet supported", _io.name.c_str());
    _io.table_size = atoi(input->NUMBER()->getText().c_str());
  }
  _io.init_values.resize(max(_io.table_size, 1), "0");
  _io.nolatch = (input->nolatch != nullptr);
}

// -------------------------------------------------

void Algorithm::gatherOutputNfo(siliceParser::OutputContext* output, t_output_nfo& _io)
{
  _io.name = output->IDENTIFIER()->getText();
  _io.table_size = 0;
  splitType(output->TYPE()->getText(), _io.type_nfo);
  if (output->NUMBER() != nullptr) {
    reportError(output->getSourceInterval(), -1, "input '%s': tables as output are not yet supported", _io.name.c_str());
    _io.table_size = atoi(output->NUMBER()->getText().c_str());
  }
  _io.init_values.resize(max(_io.table_size, 1), "0");
  _io.combinational = (output->combinational != nullptr);
}

// -------------------------------------------------

void Algorithm::gatherInoutNfo(siliceParser::InoutContext* inout, t_inout_nfo& _io)
{
  _io.name = inout->IDENTIFIER()->getText();
  _io.table_size = 0;
  splitType(inout->TYPE()->getText(), _io.type_nfo);
  if (inout->NUMBER() != nullptr) {
    reportError(inout->getSourceInterval(), -1, "inout '%s': tables as inout are not supported", _io.name.c_str());
    _io.table_size = atoi(inout->NUMBER()->getText().c_str());
  }
  _io.init_values.resize(max(_io.table_size, 1), "0");
}

// -------------------------------------------------

void Algorithm::gatherIoGroup(siliceParser::IoGroupContext* iog)
{
  // find group declaration
  auto G = m_KnownGroups.find(iog->groupid->getText());
  if (G == m_KnownGroups.end()) {
    reportError(iog->groupid,(int)iog->getStart()->getLine(),
      "no known group definition for '%s'",iog->groupid->getText().c_str());
  }
  // group prefix
  string grpre = iog->groupname->getText();
  m_VIOGroups.insert(make_pair(grpre,G->second));
  // get var list from group
  unordered_map<string,t_var_nfo> vars;
  for (auto v : G->second->varList()->var()) {
    t_var_nfo vnfo;
    gatherVarNfo(v->declarationVar(), vnfo);
    if (vars.count(vnfo.name)) {
      reportError(v->declarationVar()->IDENTIFIER()->getSymbol(),(int)v->declarationVar()->getStart()->getLine(),
        "entry '%s' declared twice in group definition '%s'",
        vnfo.name.c_str(),iog->groupid->getText().c_str());
    }
    vars.insert(make_pair(vnfo.name,vnfo));
  }
  for (auto io : iog->ioList()->io()) {
    // -> check for existence
    auto V = vars.find(io->IDENTIFIER()->getText());
    if (V == vars.end()) {
      reportError(io->IDENTIFIER()->getSymbol(), (int)io->getStart()->getLine(), 
        "'%s' not in group '%s'",io->IDENTIFIER()->getText().c_str(), iog->groupid->getText().c_str());
    }
    // add it where it belongs
    if (io->is_input != nullptr) {
      t_inout_nfo inp;
      inp.name         = grpre + "_" + V->second.name;
      inp.table_size   = V->second.table_size;
      inp.init_values  = V->second.init_values;
      inp.type_nfo     = V->second.type_nfo;
      m_Inputs.emplace_back(inp);
      m_InputNames.insert(make_pair(inp.name, (int)m_Inputs.size() - 1));
    } else if (io->is_inout != nullptr) {
      t_inout_nfo inp;
      inp.name = grpre + "_" + V->second.name;
      inp.table_size  = V->second.table_size;
      inp.init_values = V->second.init_values;
      inp.nolatch     = (io->nolatch != nullptr);
      inp.type_nfo    = V->second.type_nfo;
      m_InOuts.emplace_back(inp);
      m_InOutNames.insert(make_pair(inp.name, (int)m_InOuts.size() - 1));
    } else if (io->is_output != nullptr) {
      t_output_nfo oup;
      oup.name = grpre + "_" + V->second.name;
      oup.table_size    = V->second.table_size;
      oup.init_values   = V->second.init_values;
      oup.combinational = (io->combinational != nullptr);
      oup.type_nfo      = V->second.type_nfo;
      m_Outputs.emplace_back(oup);
      m_OutputNames.insert(make_pair(oup.name, (int)m_Outputs.size() - 1));
    }
  }
}

// -------------------------------------------------

void Algorithm::gatherIoInterface(siliceParser::IoInterfaceContext *itrf)
{
  // find interface declaration
  auto I = m_KnownInterfaces.find(itrf->interfaceid->getText());
  if (I == m_KnownInterfaces.end()) {
    reportError(itrf->interfaceid, (int)itrf->getStart()->getLine(),
      "no known interface definition for '%s'", itrf->interfaceid->getText().c_str());
  }
  // group prefix
  string grpre = itrf->groupname->getText();
  m_VIOGroups.insert(make_pair(grpre, I->second));
  // get member list from group
  unordered_set<string> vars;
  for (auto io : I->second->ioList()->io()) {
    t_var_nfo vnfo;
    vnfo.name = io->IDENTIFIER()->getText();
    vnfo.type_nfo.base_type = Parameterized;
    vnfo.type_nfo.width     = 0;
    vnfo.table_size         = 0;
    if (vars.count(vnfo.name)) {
      reportError(io->IDENTIFIER()->getSymbol(), (int)io->getStart()->getLine(),
        "entry '%s' declared twice in interface definition '%s'",
        vnfo.name.c_str(), itrf->interfaceid->getText().c_str());
    }
    vars.insert(vnfo.name);
    // add it where it belongs
    if (io->is_input != nullptr) {
      t_inout_nfo inp;
      inp.name = grpre + "_" + vnfo.name;
      inp.table_size = vnfo.table_size;
      inp.init_values = vnfo.init_values;
      inp.type_nfo = vnfo.type_nfo;
      m_Inputs.emplace_back(inp);
      m_InputNames.insert(make_pair(inp.name, (int)m_Inputs.size() - 1));
      m_Parameterized.push_back(inp.name);
    } else if (io->is_inout != nullptr) {
      t_inout_nfo inp;
      inp.name = grpre + "_" + vnfo.name;
      inp.table_size = vnfo.table_size;
      inp.init_values = vnfo.init_values;
      inp.nolatch = (io->nolatch != nullptr);
      inp.type_nfo = vnfo.type_nfo;
      m_InOuts.emplace_back(inp);
      m_InOutNames.insert(make_pair(inp.name, (int)m_InOuts.size() - 1));
      m_Parameterized.push_back(inp.name);
    } else if (io->is_output != nullptr) {
      t_output_nfo oup;
      oup.name = grpre + "_" + vnfo.name;
      oup.table_size = vnfo.table_size;
      oup.init_values = vnfo.init_values;
      oup.combinational = (io->combinational != nullptr);
      oup.type_nfo = vnfo.type_nfo;
      m_Outputs.emplace_back(oup);
      m_OutputNames.insert(make_pair(oup.name, (int)m_Outputs.size() - 1));
      m_Parameterized.push_back(oup.name);
    }
  }
}

// -------------------------------------------------

void Algorithm::gatherIOs(siliceParser::InOutListContext* inout)
{
  if (inout == nullptr) {
    return;
  }
  for (auto io : inout->inOrOut()) {
    auto input       = dynamic_cast<siliceParser::InputContext*>(io->input());
    auto output      = dynamic_cast<siliceParser::OutputContext*>(io->output());
    auto inout       = dynamic_cast<siliceParser::InoutContext*>(io->inout());
    auto iogroup     = dynamic_cast<siliceParser::IoGroupContext*>(io->ioGroup());
    auto iointerface = dynamic_cast<siliceParser::IoInterfaceContext*>(io->ioInterface());
    if (input) {
      t_inout_nfo io;
      gatherInputNfo(input, io);
      m_Inputs.emplace_back(io);
      m_InputNames.insert(make_pair(io.name, (int)m_Inputs.size() - 1));
    } else if (output) {
      t_output_nfo io;
      gatherOutputNfo(output, io);
      m_Outputs.emplace_back(io);
      m_OutputNames.insert(make_pair(io.name, (int)m_Outputs.size() - 1));
    } else if (inout) {
      t_inout_nfo io;
      gatherInoutNfo(inout, io);
      m_InOuts.emplace_back(io);
      m_InOutNames.insert(make_pair(io.name, (int)m_InOuts.size() - 1));
    } else if (iogroup) {
      gatherIoGroup(iogroup);
    } else if (iointerface) {
      gatherIoInterface(iointerface);
    } else {
      // symbol, ignore
    }
  }
}

// -------------------------------------------------

void Algorithm::getParams(siliceParser::ParamListContext* params, std::vector<antlr4::tree::ParseTree*>& _vec_params) const
{
  if (params == nullptr) return;
  while (params->expression_0() != nullptr) {
    _vec_params.push_back(params->expression_0());
    params = params->paramList();
    if (params == nullptr) return;
  }
}

// -------------------------------------------------

void Algorithm::getIdentifiers(
  siliceParser::IdentifierListContext*    idents, 
  vector<string>&                        _vec_params,
  const t_combinational_block_context*    bctx) const
{
  // go through indentifier list
  while (idents->IDENTIFIER() != nullptr) {
    std::string var = idents->IDENTIFIER()->getText();
    _vec_params.push_back(var);
    idents = idents->identifierList();
    if (idents == nullptr) return;
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

  auto algbody  = dynamic_cast<siliceParser::DeclAndInstrListContext*>(tree);
  auto decl     = dynamic_cast<siliceParser::DeclarationContext*>(tree);
  auto ilist    = dynamic_cast<siliceParser::InstructionListContext*>(tree);
  auto ifelse   = dynamic_cast<siliceParser::IfThenElseContext*>(tree);
  auto ifthen   = dynamic_cast<siliceParser::IfThenContext*>(tree);
  auto switchC  = dynamic_cast<siliceParser::SwitchCaseContext*>(tree);
  auto loop     = dynamic_cast<siliceParser::WhileLoopContext*>(tree);
  auto jump     = dynamic_cast<siliceParser::JumpContext*>(tree);
  auto assign   = dynamic_cast<siliceParser::AssignmentContext*>(tree);
  auto display  = dynamic_cast<siliceParser::DisplayContext *>(tree);
  auto async    = dynamic_cast<siliceParser::AsyncExecContext*>(tree);
  auto join     = dynamic_cast<siliceParser::JoinExecContext*>(tree);
  auto sync     = dynamic_cast<siliceParser::SyncExecContext*>(tree);
  auto circinst = dynamic_cast<siliceParser::CircuitryInstContext*>(tree);
  auto repeat   = dynamic_cast<siliceParser::RepeatBlockContext*>(tree);
  auto pip      = dynamic_cast<siliceParser::PipelineContext*>(tree);
  auto call     = dynamic_cast<siliceParser::CallContext*>(tree);
  auto ret      = dynamic_cast<siliceParser::ReturnFromContext*>(tree);
  auto breakL   = dynamic_cast<siliceParser::BreakLoopContext*>(tree);
  auto block    = dynamic_cast<siliceParser::BlockContext *>(tree);

  bool recurse  = true;

  if (algbody) {
    // gather declarations
    for (auto d : algbody->declaration()) {
      gatherDeclaration(dynamic_cast<siliceParser::DeclarationContext *>(d), _current, _context, false);
    }
    for (auto s : algbody->subroutine()) {
      gatherSubroutine(dynamic_cast<siliceParser::SubroutineContext *>(s), _current, _context);
    }
    // gather always assigned
    gatherAlwaysAssigned(algbody->alwaysPre, &m_AlwaysPre);
    m_AlwaysPre.context.parent_scope = _current;
    // gather always block if defined
    if (algbody->alwaysBlock() != nullptr) {
      gather(algbody->alwaysBlock(),&m_AlwaysPre,_context);
      if (!isStateLessGraph(&m_AlwaysPre)) {
        reportError(algbody->alwaysBlock()->ALWAYS()->getSymbol(),
          (int)algbody->alwaysBlock()->getStart()->getLine(),
          "always block can only be combinational");
      }
    }
    // add global subroutines now (reparse them as if defined in this algorithm)
    for (const auto& s : m_KnownSubroutines) {
      gatherSubroutine(s.second, _current, _context);
    }
    // recurse on instruction list
    _current = gather(algbody->instructionList(), _current, _context);
    recurse  = false;
  } else if (decl)     { gatherDeclaration(decl, _current, _context, true);  recurse = false;
  } else if (ifelse)   { _current = gatherIfElse(ifelse, _current, _context);          recurse = false;
  } else if (ifthen)   { _current = gatherIfThen(ifthen, _current, _context);          recurse = false;
  } else if (switchC)  { _current = gatherSwitchCase(switchC, _current, _context);     recurse = false;
  } else if (loop)     { _current = gatherWhile(loop, _current, _context);             recurse = false;
  } else if (repeat)   { _current = gatherRepeatBlock(repeat, _current, _context);     recurse = false;
  } else if (pip)      { _current = gatherPipeline(pip, _current, _context);           recurse = false;
  } else if (sync)     { _current = gatherSyncExec(sync, _current, _context);          recurse = false;
  } else if (join)     { _current = gatherJoinExec(join, _current, _context);          recurse = false;
  } else if (call)     { _current = gatherCall(call, _current, _context);              recurse = false;
  } else if (circinst) { _current = gatherCircuitryInst(circinst, _current, _context); recurse = false;
  } else if (jump)     { _current = gatherJump(jump, _current, _context);              recurse = false; 
  } else if (ret)      { _current = gatherReturnFrom(ret, _current, _context);         recurse = false;
  } else if (breakL)   { _current = gatherBreakLoop(breakL, _current, _context);       recurse = false;
  } else if (async)    { _current->instructions.push_back(t_instr_nfo(async, _context->__id));   recurse = false; 
  } else if (assign)   { _current->instructions.push_back(t_instr_nfo(assign, _context->__id));  recurse = false;
  } else if (display)  { _current->instructions.push_back(t_instr_nfo(display, _context->__id)); recurse = false; 
  } else if (block)    { _current = gatherBlock(block, _current, _context);            recurse = false;
  } else if (ilist)    { _current = splitOrContinueBlock(ilist, _current, _context); }

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
      reportError(
        refs.second.front().jump->getSourceInterval(),
        (int)refs.second.front().jump->getStart()->getLine(),
        "%s", msg.c_str());
    } else {
      for (auto& j : refs.second) {
        if (dynamic_cast<siliceParser::JumpContext*>(j.jump)) {
          // update jump
          j.from->next(B->second);
        } else if (dynamic_cast<siliceParser::CallContext*>(j.jump)) {
          // update call
          const end_action_goto_and_return_to* gaf = j.from->goto_and_return_to();
          j.from->goto_and_return_to(B->second, gaf->return_to);
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
  if (requiresNoReset()) {
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
  // TODO: fastforward, but not so simple, can lead to trouble with var inits, 
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

int Algorithm::stateWidth(int max_state) const
{
  int w = 0;
  while (max_state > (1 << w)) {
    w++;
  }
  return w;
}

// -------------------------------------------------

int Algorithm::stateWidth() const
{
  return stateWidth(maxState());
}

// -------------------------------------------------

const Algorithm::t_combinational_block *Algorithm::fastForward(const t_combinational_block *block) const
{
  sl_assert(block->is_state);
  const t_combinational_block *current = block;
  const t_combinational_block *last_state = block;
  while (true) {
    if (current->no_skip) {
      // no skip, stop here
      return last_state;
    }
    if (!current->instructions.empty()) {
      // non-empty, stop here
      return last_state;
    }
    if (current->next() == nullptr) {
      // not a simple jump, stop here
      return last_state;
    } else {
      current = current->next()->next;
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
        auto A = m_InstancedAlgorithms.find(call->joinExec()->IDENTIFIER()->getText());
        if (A == m_InstancedAlgorithms.end()) { // not a call to algorithm?
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

bool Algorithm::requiresNoReset() const
{
  if (!hasNoFSM()) {
    return false;
  }
  for (const auto &v : m_Vars) {
    if (v.usage != e_FlipFlop) continue;
    if (!v.do_not_initialize) {
      return false;
    }
  }
  return true;
}

// -------------------------------------------------

void Algorithm::updateAndCheckDependencies(t_vio_dependencies& _depds, antlr4::tree::ParseTree* instr, const t_combinational_block_context *bctx) const
{
  if (instr == nullptr) {
    return;
  }
  // record which vars were written before
  std::unordered_set<std::string> written_before;
  for (const auto &d : _depds.dependencies) {
    written_before.insert(d.first);
  }
  // determine VIOs accesses for instruction
  std::unordered_set<std::string> read;
  std::unordered_set<std::string> written;
  determineVIOAccess(instr, m_VarNames, bctx, read, written);
  determineVIOAccess(instr, m_InputNames, bctx, read, written);
  determineVIOAccess(instr, m_OutputNames, bctx, read, written);
  // for each written var, collapse dependencies
  // -> union dependencies of all read vars
  std::unordered_set<std::string> upstream;
  for (const auto& r : read) {
    // insert r in dependencies
    upstream.insert(r);
    // add its dependencies
    auto D = _depds.dependencies.find(r);
    if (D != _depds.dependencies.end()) {
      for (auto d : D->second) {
        upstream.insert(d);
      }
    }
  }
  // -> replace dependencies of written vars
  for (const auto& w : written) {
    _depds.dependencies[w] = upstream;
  }

  /// DEBUG
  if (0) {
    std::cerr << "---- after line " << dynamic_cast<antlr4::ParserRuleContext*>(instr)->getStart()->getLine() << nxl;
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
    // check if the variable was written before and depends on self
    if (written_before.count(w) > 0) {
      // yes: does it depend on itself?
      const auto& d = _depds.dependencies.at(w);
      if (d.count(w) > 0) {
        // yes: this would produce a combinational cycle, error!
        reportError(
          dynamic_cast<antlr4::ParserRuleContext *>(instr)->getSourceInterval(),
          (int)(dynamic_cast<antlr4::ParserRuleContext *>(instr)->getStart()->getLine()),
          "variable assignement leads to a combinational cycle (variable: '%s')\n\nConsider inserting a sequential split with '++:'",
          w.c_str());
      }
    }
    // check if the variable depends on a wire, that depends on the variable itself
    for (const auto &d : _depds.dependencies.at(w)) {
      if (_depds.dependencies.count(d) > 0) { // is this dependency also dependent on other vars?
        if (m_VarNames.count(d) > 0) { // yes, is it a variable?
          if (m_Vars.at(m_VarNames.at(d)).usage == e_Wire) { // is it a wire?
            if (_depds.dependencies.at(d).count(w)) { // depends on written var?
              // yes: this would produce a combinational cycle, error!
              reportError(
                dynamic_cast<antlr4::ParserRuleContext *>(instr)->getSourceInterval(),
                (int)(dynamic_cast<antlr4::ParserRuleContext *>(instr)->getStart()->getLine()),
                "variable assignement leads to a combinational cycle through variable bound to expression\n\n(variable: '%s', through '%s').",
                w.c_str(), d.c_str());
            }
          }
        }
      }
    }
    // now check for combinational cycles through algorithm bindings
    for (const auto& alg : m_InstancedAlgorithms) {      
      // gather bindings potentially creating comb. cycles
      unordered_set<string> i_bounds,o_bounds;
      for (const auto& b : alg.second.bindings) {        
        if (b.dir == e_Left) { // NOTE: we ignore e_LeftQ as these cannot produce comb. cycles
          // find right indentifier
          std::string i_bound = bindingRightIdentifier(b);
          if (_depds.dependencies.count(i_bound) > 0) {
            i_bounds.insert(i_bound);
          }
        } else if (b.dir == e_Right) {
          const auto& O = alg.second.algo->m_OutputNames.find(b.left);
          if (O != alg.second.algo->m_OutputNames.end()) {
            if (alg.second.algo->m_Outputs[O->second].combinational) {
              std::string o_bound = bindingRightIdentifier(b);
              o_bounds.insert(o_bound);
            }
          }
        }
      }
      // now check
      for (const auto& i : i_bounds) {
        if (_depds.dependencies.count(i) > 0) { // input is being written
          // depends on a combinational output?
          for (const auto& o : o_bounds) {
            if (_depds.dependencies.at(i).count(o) > 0) {
              // cycle!
              reportError(
                dynamic_cast<antlr4::ParserRuleContext *>(instr)->getSourceInterval(),
                (int)(dynamic_cast<antlr4::ParserRuleContext *>(instr)->getStart()->getLine()),
                "assignement to algorithm input leads to a combinational cycle\n\n(input '%s' instance '%s' through output '%s')",
                i.c_str(), alg.second.algo_name.c_str(), o.c_str());
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

void Algorithm::resetFFUsageLatches(t_vio_ff_usage &_ff) const
{
  for (auto& v : _ff.ff_usage) {
    v.second = (e_FFUsage)((int)v.second & (~e_Latch));
  }
}

// -------------------------------------------------

void Algorithm::combineFFUsageInto(const t_vio_ff_usage &ff_before, std::vector<t_vio_ff_usage> &ff_branches, t_vio_ff_usage& _ff_after) const
{
  t_vio_ff_usage ff_after = _ff_after; // do not manipulate _ff_after as it is typically a ref to ff_before as well
  // find if some vars are e_D *only* in all branches
  set<string> d_in_all;
  bool first = true;
  for (const auto& br : ff_branches) {
    set<string> d_in_br;
    for (auto& v : br.ff_usage) {
      if (v.second == e_D) { // exactly D (not Q, not latched next)
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
      if ((v.second & e_D) && !(v.second & e_Q)) { // D but not Q
        if (d_in_all.count(v.first) == 0) { // not used in all branches? => latch if used next
          ff_after.ff_usage[v.first] = (e_FFUsage)((int)ff_after.ff_usage[v.first] | e_Latch);
        }
      }
    }
  }
  _ff_after = ff_after;
}

// -------------------------------------------------

void Algorithm::verifyMemberGroup(std::string member, siliceParser::GroupContext* group, int line) const
{
  // -> check for existence
  for (auto v : group->varList()->var()) {
    if (v->declarationVar()->IDENTIFIER()->getText() == member) {
      return; // ok!
    }
  }
  reportError(group->IDENTIFIER()->getSymbol(),line,"group '%s' does not contain a member '%s'",
    group->IDENTIFIER()->getText().c_str(), member.c_str(), line);
}

// -------------------------------------------------

void Algorithm::verifyMemberInterface(std::string member, siliceParser::IntrfaceContext *intrface, int line) const
{
  // -> check for existence
  for (auto io : intrface->ioList()->io()) {
    if (io->IDENTIFIER()->getText() == member) {
      return; // ok!
    }
  }
  reportError(intrface->IDENTIFIER()->getSymbol(), line, "interface '%s' does not contain a member '%s'",
    intrface->IDENTIFIER()->getText().c_str(), member.c_str(), line);
}

// -------------------------------------------------

void Algorithm::verifyMemberGroup(std::string member, const t_group_definition &gd, int line) const
{
  if (gd.group != nullptr) {
    verifyMemberGroup(member, gd.group, line);
  } else if (gd.intrface != nullptr) {
    verifyMemberInterface(member, gd.intrface, line);
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
  }
  return mbs;
}

// -------------------------------------------------

void Algorithm::verifyMemberBitfield(std::string member, siliceParser::BitfieldContext* field, int line) const
{
  // -> check for existence
  for (auto v : field->varList()->var()) {
    if (v->declarationVar()->IDENTIFIER()->getText() == member) {
      // verify there is no initializer
      if (v->declarationVar()->value() != nullptr) {
        reportError(v->declarationVar()->getSourceInterval(), (int)v->declarationVar()->value()->getStart()->getLine(),
          "bitfield members should not be given initial values (field '%s', member '%s')",
          field->IDENTIFIER()->getText().c_str(), member.c_str());
      }
      // verify type is uint
      sl_assert(v->declarationVar()->TYPE() != nullptr);
      string test = v->declarationVar()->TYPE()->getText();
      if (v->declarationVar()->TYPE()->getText()[0] != 'u') {
        reportError(v->declarationVar()->getSourceInterval(), (int)v->declarationVar()->getStart()->getLine(),
          "bitfield members can only be unsigned (field '%s', member '%s')",
          field->IDENTIFIER()->getText().c_str(), member.c_str());
      }
      return; // ok!
    }
  }
  reportError(nullptr, line, "bitfield '%s' does not contain a member '%s'",
    field->IDENTIFIER()->getText().c_str(), member.c_str(), line);
}

// -------------------------------------------------

std::string Algorithm::bindingRightIdentifier(const t_binding_nfo& bnd, const t_combinational_block_context* bctx) const
{
  if (bnd.right_access == nullptr) {
    return translateVIOName(bnd.right_identifier, bctx);
  } else {
    return determineAccessedVar(bnd.right_access, bctx);
  }
}

// -------------------------------------------------

std::string Algorithm::determineAccessedVar(siliceParser::IoAccessContext* access,const t_combinational_block_context* bctx) const
{
  std::string base = access->base->getText();
  base = translateVIOName(base, bctx);
  if (access->IDENTIFIER().size() != 2) {
    reportError(access->getSourceInterval(),(int)access->getStart()->getLine(),"'.' access depth limited to one in current version '%s'", base.c_str());
  }
  std::string member = access->IDENTIFIER()[1]->getText();
  // find algorithm
  auto A = m_InstancedAlgorithms.find(base);
  if (A != m_InstancedAlgorithms.end()) {
    return ""; // no var accessed in this case
  } else {
    auto G = m_VIOGroups.find(base);
    if (G != m_VIOGroups.end()) {
      verifyMemberGroup(member, G->second, (int)access->getStart()->getLine());
      // return the group member name
      return base + "_" + member;
    } else {
      reportError(access->getSourceInterval(), (int)access->getStart()->getLine(),
        "cannot find access base.member '%s.%s'", base.c_str(), member.c_str());
    }
  }
  return "";
}

// -------------------------------------------------

std::string Algorithm::determineAccessedVar(siliceParser::BitfieldAccessContext* bfaccess, const t_combinational_block_context* bctx) const
{
  if (bfaccess->idOrIoAccess()->ioAccess() != nullptr) {
    return determineAccessedVar(bfaccess->idOrIoAccess()->ioAccess(), bctx);
  } else {
    return bfaccess->idOrIoAccess()->IDENTIFIER()->getText();
  }
}

// -------------------------------------------------

std::string Algorithm::determineAccessedVar(siliceParser::BitAccessContext* access,const t_combinational_block_context* bctx) const
{
  if (access->ioAccess() != nullptr) {
    return determineAccessedVar(access->ioAccess(), bctx);
  } else if (access->tableAccess() != nullptr) {
    return determineAccessedVar(access->tableAccess(), bctx);
  } else {
    return access->IDENTIFIER()->getText();
  }
}

// -------------------------------------------------

std::string Algorithm::determineAccessedVar(siliceParser::TableAccessContext* access,const t_combinational_block_context* bctx) const
{
  if (access->ioAccess() != nullptr) {
    return determineAccessedVar(access->ioAccess(), bctx);
  } else {
    return access->IDENTIFIER()->getText();
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
  } else if (access->bitAccess() != nullptr) {
    return determineAccessedVar(access->bitAccess(), bctx);
  } else if (access->bitfieldAccess() != nullptr) {
    return determineAccessedVar(access->bitfieldAccess(), bctx);
  }
  reportError(nullptr,(int)access->getStart()->getLine(), "internal error [%s, %d]",  __FILE__, __LINE__);
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
        if (vios.find(var) != vios.end()) {
          _read.insert(var);
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
          } else if (assign->access()->bitAccess() != nullptr) {
            determineVIOAccess(assign->access()->bitAccess()->expression_0(), vios, bctx, _read, _written);
            // This is a bit access. We assume it is partial (could be checked if const).
            // Thus the variable is likely only partially written and to be safe we tag
            // it as 'read' since other bits are likely read later in the execution flow.
            // This is a conservative assumption. A bit-per-bit analysis could be envisioned, 
            // but for lack of it we have no other choice here to avoid generating wrong code.
            // See also issue #54.
            if (!var.empty() && vios.find(var) != vios.end()) {
              _read.insert(var);
            }
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
          } else if (alw->access()->bitAccess() != nullptr) {
            determineVIOAccess(alw->access()->bitAccess()->expression_0(), vios, bctx, _read, _written);
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
      auto join = dynamic_cast<siliceParser::JoinExecContext*>(node);
      if (join) {
        // track writes when reading back
        for (const auto& asgn : join->assignList()->assign()) {
          std::string var;
          if (asgn->access() != nullptr) {
            var = determineAccessedVar(asgn->access(), bctx);
          } else {
            var = asgn->IDENTIFIER()->getText();
          }
          if (!var.empty()) {
            var = translateVIOName(var, bctx);
            if (!var.empty() && vios.find(var) != vios.end()) {
              _written.insert(var);
            }
          }
          // recurse on lhs expression, if any
          if (asgn->access() != nullptr) {
            if (asgn->access()->tableAccess() != nullptr) {
              determineVIOAccess(asgn->access()->tableAccess()->expression_0(), vios, bctx, _read, _written);
            } else if (asgn->access()->bitAccess() != nullptr) {
              determineVIOAccess(asgn->access()->bitAccess()->expression_0(), vios, bctx, _read, _written);
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

void Algorithm::determineVariablesAndOutputsAccess(
  antlr4::tree::ParseTree             *instr,
  const t_combinational_block_context *context,
  std::unordered_set<std::string>& _already_written,
  std::unordered_set<std::string>& _in_vars_read,
  std::unordered_set<std::string>& _out_vars_written
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

void Algorithm::determineVariablesAndOutputsAccess(t_combinational_block *block)
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
    determineVariablesAndOutputsAccess(i.instr, &block->context, already_written, block->in_vars_read, block->out_vars_written);
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
        reportError(nullptr, b.line, "cannot write to variable '%s' bound to an algorithm or module output", bindingRightIdentifier(b).c_str());
      }
      // -> mark as write-binded
      _nfos[names.at(bindingRightIdentifier(b))].access = (e_Access)(_nfos[names.at(bindingRightIdentifier(b))].access | e_WriteBinded);
    } else { // e_BiDir
      sl_assert(b.dir == e_BiDir);
      // -> check prior access
      if ((_nfos[names.at(bindingRightIdentifier(b))].access & (~e_ReadWriteBinded)) != 0) {
        reportError(nullptr, b.line, "cannot bind variable '%s' on an inout port, it is used elsewhere", bindingRightIdentifier(b).c_str());
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

void Algorithm::determineVariablesAndOutputsAccessForWires(
  std::unordered_set<std::string> &_global_in_read,
  std::unordered_set<std::string> &_global_out_written
) {
  t_combinational_block_context empty;
  // first we gather all wires (bound expressions)
  std::unordered_map<std::string, siliceParser::AlwaysAssignedContext*> all_wires;
  std::queue<std::string> q_wires;
  for (const auto &v : m_Vars) {
    if (v.usage == e_Wire) { // this is a wire (bound expression)
      // find corresponding wire assignement
      auto alw = dynamic_cast<siliceParser::AlwaysAssignedContext *>(m_WireAssignments.at(v.name).instr);
      sl_assert(alw != nullptr);
      sl_assert(alw->IDENTIFIER() != nullptr);
      string var = translateVIOName(alw->IDENTIFIER()->getText(), &empty);
      if (var == v.name) { // found it
        all_wires.insert(make_pair(v.name, alw));
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
      determineVariablesAndOutputsAccess(all_wires.at(w), &empty, _, in_read, _global_out_written);
      // foreach read vio
      for (auto v : in_read) {
        // insert in global set
        _global_in_read.insert(v);
        // check if this used a new wire?          
        if (all_wires.count(v) > 0 && processed.count(v) == 0) {
          // promote as accessed
          m_Vars.at(m_VarNames.at(v)).access = e_ReadOnly;
          // recurse
          q_wires.push(v);
        }
      }
    }
  }

}

// -------------------------------------------------

void Algorithm::determineVariablesAndOutputsAccess(
  std::unordered_set<std::string>& _global_in_read,
  std::unordered_set<std::string>& _global_out_written
)
{
  // for all blocks
  for (auto& b : m_Blocks) {
    if (b->state_id == -1 && b->is_state) {
      continue; // block is never reached
    }
    determineVariablesAndOutputsAccess(b);
  }
  // determine variable access for always blocks
  determineVariablesAndOutputsAccess(&m_AlwaysPre);
  // determine variable access for wires
  determineVariablesAndOutputsAccessForWires(_global_in_read, _global_out_written);
  // determine variable access due to algorithm and module instances
  // bindings are considered as belonging to the always pre block
  std::vector<t_binding_nfo> all_bindings;
  for (const auto& m : m_InstancedModules) {
    all_bindings.insert(all_bindings.end(), m.second.bindings.begin(), m.second.bindings.end());
  }
  for (const auto& a : m_InstancedAlgorithms) {
    all_bindings.insert(all_bindings.end(), a.second.bindings.begin(), a.second.bindings.end());
  }
  for (const auto& b : all_bindings) {
    // variables
    updateAccessFromBinding(b, m_VarNames, m_Vars);
    // outputs
    updateAccessFromBinding(b, m_OutputNames, m_Outputs);
  }
  // determine variable access due to algorithm instances clocks and reset
  for (const auto& m : m_InstancedAlgorithms) {
    std::vector<std::string> candidates;
    candidates.push_back(m.second.instance_clock);
    candidates.push_back(m.second.instance_reset);
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
    for (auto& inv : mem.in_vars) {
      // add to always block dependency
      m_AlwaysPost.in_vars_read.insert(inv);
      // set global access
      m_Vars[m_VarNames[inv]].access = (e_Access)(m_Vars[m_VarNames[inv]].access | e_ReadOnly);
    }
    for (auto& ouv : mem.out_vars) {
      // add to always block dependency
      m_AlwaysPre.out_vars_written.insert(ouv);
      // -> check prior access
      if (m_Vars[m_VarNames[ouv]].access & e_WriteOnly) {
        reportError(nullptr, mem.line, "cannot write to variable '%s' bound to a memory output", ouv.c_str());
      }
      // set global access
      m_Vars[m_VarNames[ouv]].access = (e_Access)(m_Vars[m_VarNames[ouv]].access | e_WriteBinded);
    }
  }
  // merge all in_reads and out_written
  auto all_blocks = m_Blocks;
  all_blocks.push_front(&m_AlwaysPre);
  all_blocks.push_front(&m_AlwaysPost);
  for (const auto &b : all_blocks) {
    _global_in_read.insert(b->in_vars_read.begin(), b->in_vars_read.end());
    _global_out_written.insert(b->out_vars_written.begin(), b->out_vars_written.end());
  }
}

// -------------------------------------------------

void Algorithm::determineVariableAndOutputsUsage()
{

  // NOTE The notion of block here ignores combinational chains. For this reason this is only a 
  //      coarse pass, and a second, finer analysis is performed through the two-passes write (see writeAsModule). 
  //      This pass is still useful to detect (in particular) consts.

  // determine variables access
  std::unordered_set<std::string> global_in_read;
  std::unordered_set<std::string> global_out_written;
  determineVariablesAndOutputsAccess(global_in_read, global_out_written);
  // set and report
  const bool report = false;
  if (report) std::cerr << "---< " << m_Name << "::variables >---" << nxl;
  for (auto& v : m_Vars) {
    if (v.usage != e_Undetermined) {
      switch (v.usage) {
      case e_Wire: if (report) std::cerr << v.name << " => wire (by def)" << nxl; break;
      default: throw Fatal("interal error");
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
    } else if (v.access == e_ReadWrite) {
      if ( v.table_size == 0  // tables are not allowed to become temporary registers
        && global_in_read.find(v.name) == global_in_read.end()) {
        if (report) std::cerr << v.name << " => temp ";
        v.usage = e_Temporary;
      } else {
        if (report) std::cerr << v.name << " => flip-flop ";
        v.usage = e_FlipFlop;
      }
    } else if (v.access == (e_WriteBinded | e_ReadOnly)) {
      if (report) std::cerr << v.name << " => write-binded ";
      v.usage = e_Bound;
    } else if (v.access == (e_WriteBinded)) {
      if (report) std::cerr << v.name << " => write-binded but not used ";
      v.usage = e_Bound;
    } else if (v.access == e_NotAccessed) {
      if (report) std::cerr << v.name << " => unused ";
      v.usage = e_NotUsed;
    } else if (v.access == e_ReadWriteBinded) {
      if (report) std::cerr << v.name << " => bound to inout ";
      v.usage = e_Bound;
    } else if ((v.access & e_InternalFlipFlop) == e_InternalFlipFlop) {
      if (report) std::cerr << v.name << " => internal flip-flop ";
      v.usage = e_FlipFlop;
    } else {
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

#if 0
  /////////// DEBUG
  for (const auto& v : m_Vars) {
    cerr << v.name << " access: ";
    if (v.access & e_ReadOnly) cerr << 'R';
    if (v.access & e_WriteOnly) cerr << 'W';
    std::cerr << nxl;
  }
  for (const auto& b : all_blocks) {
    std::cerr << "== block " << b->block_name << "==" << nxl;
    std::cerr << "   read from before: ";
    for (auto i : b->in_vars_read) {
      std::cerr << i << ' ';
    }
    std::cerr << nxl;
    std::cerr << "   changed within: ";
    for (auto i : b->out_vars_written) {
      std::cerr << i << ' ';
    }
    std::cerr << nxl;
  }
  /////////////////
#endif

}

// -------------------------------------------------

void Algorithm::determineModAlgBoundVIO()
{
  // find out vio bound to a module input/output
  for (const auto& im : m_InstancedModules) {
    for (const auto& b : im.second.bindings) {
      if (b.dir == e_Right) {
        // record wire name for this output
        m_VIOBoundToModAlgOutputs[bindingRightIdentifier(b)] = WIRE + im.second.instance_prefix + "_" + b.left;
      } else if (b.dir == e_BiDir) {
        // record wire name for this inout
        std::string bindpoint = im.second.instance_prefix + "_" + b.left;
        m_ModAlgInOutsBoundToVIO[bindpoint] = bindingRightIdentifier(b);
      }
    }
  }
  // find out vio bound to an algorithm output
  for (const auto& ia : m_InstancedAlgorithms) {
    for (const auto& b : ia.second.bindings) {
      if (b.dir == e_Right) {
        // record wire name for this output
        m_VIOBoundToModAlgOutputs[bindingRightIdentifier(b)] = WIRE + ia.second.instance_prefix + "_" + b.left;
      } else if (b.dir == e_BiDir) {
        // record wire name for this inout
        std::string bindpoint = ia.second.instance_prefix + "_" + b.left;
        m_ModAlgInOutsBoundToVIO[bindpoint] = bindingRightIdentifier(b);
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::analyzeSubroutineCalls()
{
  for (const auto &b : m_Blocks) {
    if (b->state_id == -1 && b->is_state) {
      continue; // block is never reached
    }
    // contains a subroutine call?
    for (auto i : b->instructions) {
      if (b->goto_and_return_to()) {
        if (b->goto_and_return_to()->go_to->context.subroutine != nullptr) {
          // record return state
          m_SubroutinesCallerReturnStates[b->goto_and_return_to()->go_to->context.subroutine->name]
            .insert(std::make_pair(
              b->parent_state_id,
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
}

// -------------------------------------------------

void Algorithm::analyzeInstancedAlgorithmsInputs()
{
  for (auto& ia : m_InstancedAlgorithms) {
    for (const auto& b : ia.second.bindings) {
      if (b.dir == e_Left || b.dir == e_LeftQ) { // setting input
        // input is bound directly
        ia.second.boundinputs.insert(make_pair(b.left, make_pair(bindingRightIdentifier(b),b.dir == e_LeftQ ? e_Q : e_D)));
      }
    }
  }
}

// -------------------------------------------------

Algorithm::Algorithm(
  std::string name, 
  std::string clock, std::string reset, 
  bool autorun, bool onehot,
  const std::unordered_map<std::string, AutoPtr<Module> >& known_modules,
  const std::unordered_map<std::string, siliceParser::SubroutineContext*>& known_subroutines,
  const std::unordered_map<std::string, siliceParser::CircuitryContext*>&  known_circuitries,
  const std::unordered_map<std::string, siliceParser::GroupContext*>&      known_groups,
  const std::unordered_map<std::string, siliceParser::IntrfaceContext *>& known_interfaces,
  const std::unordered_map<std::string, siliceParser::BitfieldContext*>&   known_bitfield
)
  : m_Name(name), m_Clock(clock), m_Reset(reset), 
    m_AutoRun(autorun), m_OneHot(onehot), 
  m_KnownModules(known_modules), m_KnownSubroutines(known_subroutines), 
  m_KnownCircuitries(known_circuitries), m_KnownGroups(known_groups), 
  m_KnownInterfaces(known_interfaces), m_KnownBitFields(known_bitfield)
{
  // init with empty always blocks
  m_AlwaysPre.id = 0;
  m_AlwaysPre.block_name = "_always_pre";
}

// -------------------------------------------------

void Algorithm::gather(siliceParser::InOutListContext *inout, antlr4::tree::ParseTree *declAndInstr)
{
  // gather elements from source code
  t_combinational_block *main = addBlock("_top", nullptr, nullptr, (int)inout->getStart()->getLine());
  main->is_state = true;

  // gather input and outputs
  gatherIOs(inout);

  // semantic pass
  t_gather_context context;
  context.__id = -1;
  context.break_to = nullptr;
  gather(declAndInstr, main, &context);

  // resolve forward refs
  resolveForwardJumpRefs();

  // generate states
  generateStates();
}

// -------------------------------------------------

void Algorithm::resolveAlgorithmRefs(const std::unordered_map<std::string, AutoPtr<Algorithm> >& algorithms)
{
  for (auto& nfo : m_InstancedAlgorithms) {
    const auto& A = algorithms.find(nfo.second.algo_name);
    if (A == algorithms.end()) {
      reportError(nullptr, nfo.second.instance_line, "algorithm '%s' not found, instance '%s'",
        nfo.second.algo_name.c_str(),
        nfo.second.instance_name.c_str());
    }
    nfo.second.algo = A->second;
    // resolve any automatic directional bindings
    resolveInstancedAlgorithmBindingDirections(nfo.second);
    // perform autobind
    if (nfo.second.autobind) {
      autobindInstancedAlgorithm(nfo.second);
    }
  }
}

// -------------------------------------------------

void Algorithm::resolveModuleRefs(const std::unordered_map<std::string, AutoPtr<Module> >& modules)
{
  for (auto& nfo : m_InstancedModules) {
    const auto& M = modules.find(nfo.second.module_name);
    if (M == modules.end()) {
      reportError(nullptr, nfo.second.instance_line, "module '%s' not found, instance '%s'",
        nfo.second.module_name.c_str(),
        nfo.second.instance_name.c_str());
    }
    nfo.second.mod = M->second;
    // check autobind
    if (nfo.second.autobind) {
      autobindInstancedModule(nfo.second);
    }
  }
}

// -------------------------------------------------

void Algorithm::checkPermissions()
{
  // check permissions on all instructions of all blocks
  for (const auto &i : m_AlwaysPre.instructions) {
    checkPermissions(i.instr, &m_AlwaysPre);
  }
  for (const auto &b : m_Blocks) {
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

void Algorithm::checkExpressions(antlr4::tree::ParseTree *node, const t_combinational_block *_current)
{
  auto expr   = dynamic_cast<siliceParser::Expression_0Context*>(node);
  auto assign = dynamic_cast<siliceParser::AssignmentContext*>(node);
  auto alwasg = dynamic_cast<siliceParser::AlwaysAssignedContext*>(node);
  auto async  = dynamic_cast<siliceParser::AsyncExecContext *>(node);
  auto sync   = dynamic_cast<siliceParser::SyncExecContext *>(node);
  auto join   = dynamic_cast<siliceParser::JoinExecContext *>(node);
  if (expr) {
    ExpressionLinter linter(this);
    linter.lint(expr, &_current->context);
  } else if (assign) {
    ExpressionLinter linter(this);
    linter.lintAssignment(assign->access(),assign->IDENTIFIER(), assign->expression_0(), &_current->context);
  } else if (alwasg) { 
    ExpressionLinter linter(this);
    linter.lintAssignment(alwasg->access(), alwasg->IDENTIFIER(), alwasg->expression_0(), &_current->context);
  } else if (async) {
    // get params
    std::vector<antlr4::tree::ParseTree*> params;
    getParams(async->paramList(), params);
    if (!params.empty()) {
      // find algorithm
      auto A = m_InstancedAlgorithms.find(async->IDENTIFIER()->getText());
      if (A != m_InstancedAlgorithms.end()) {
        int p = 0;
        for (const auto& ins : A->second.algo->m_Inputs) {
          ExpressionLinter linter(this);
          linter.lintInputParameter(ins.name, ins.type_nfo, dynamic_cast<siliceParser::Expression_0Context*>(params[p++]), &_current->context);
        }
      }
    }
  } else if (sync) {
    // get params
    std::vector<antlr4::tree::ParseTree*> params;
    getParams(sync->paramList(), params);
    if (!params.empty()) {
      // find algorithm / subroutine
      auto A = m_InstancedAlgorithms.find(sync->joinExec()->IDENTIFIER()->getText());
      if (A != m_InstancedAlgorithms.end()) { // algorithm
        int p = 0;
        for (const auto& ins : A->second.algo->m_Inputs) {
          if (p >= params.size()) { break; } // safety in case of wrong num params
          ExpressionLinter linter(this);
          linter.lintInputParameter(ins.name, ins.type_nfo, dynamic_cast<siliceParser::Expression_0Context*>(params[p++]), &_current->context);
        }
      } else {
        auto S = m_Subroutines.find(sync->joinExec()->IDENTIFIER()->getText());
        if (S != m_Subroutines.end()) { // subroutine
          int p = 0;
          for (const auto& ins : S->second->inputs) {
            if (p >= params.size()) { break; } // safety in case of wrong num params
            // skip inputs which are not used
            const auto& info = m_Vars[m_VarNames.at(S->second->vios.at(ins))];
            if (info.access == e_WriteOnly) {
              p++;
              continue;
            }
            ExpressionLinter linter(this);
            linter.lintInputParameter(ins, info.type_nfo, dynamic_cast<siliceParser::Expression_0Context*>(params[p++]), &_current->context);
          }
        }
      }
    }
  } else if (join) {
    if (!join->assignList()->assign().empty()) {
      // find algorithm / subroutine
      auto A = m_InstancedAlgorithms.find(join->IDENTIFIER()->getText());
      if (A != m_InstancedAlgorithms.end()) { // algorithm
        int p = 0;
        for (const auto& outs : A->second.algo->m_Outputs) {
          if (p >= join->assignList()->assign().size()) { break; } // safety in case of wrong num params
          ExpressionLinter linter(this);
          linter.lintReadback(outs.name, join->assignList()->assign()[p]->access(), join->assignList()->assign()[p]->IDENTIFIER(), outs.type_nfo, &_current->context);
          ++p;
        }
      } else {
        auto S = m_Subroutines.find(join->IDENTIFIER()->getText());
        if (S != m_Subroutines.end()) { // subroutine
          int p = 0;
          for (const auto& outs : S->second->outputs) {
            if (p >= join->assignList()->assign().size()) { break; } // safety in case of wrong num params
            ExpressionLinter linter(this);
            const auto& info = m_Vars[m_VarNames.at(S->second->vios.at(outs))];
            linter.lintReadback(outs, join->assignList()->assign()[p]->access(), join->assignList()->assign()[p]->IDENTIFIER(), info.type_nfo, &_current->context);
            ++p;
          }
        }
      }
    }
  } else {
    for (auto c : node->children) {
      checkExpressions(c, _current);
    }
  }
}

// -------------------------------------------------

void Algorithm::checkExpressions()
{
  // check permissions on all instructions of all blocks
  for (const auto &i : m_AlwaysPre.instructions) {
    checkExpressions(i.instr, &m_AlwaysPre);
  }
  for (const auto &b : m_Blocks) {
    for (const auto &i : b->instructions) {
      checkExpressions(i.instr, b);
    }
    // check expressions in flow control
    if (b->if_then_else()) {
      checkExpressions(b->if_then_else()->test.instr, b);
    }
    if (b->switch_case()) {
      checkExpressions(b->switch_case()->test.instr, b);
    }
    if (b->while_loop()) {
      checkExpressions(b->while_loop()->test.instr, b);
    }
  }
}

// -------------------------------------------------

void Algorithm::optimize()
{
  // check bindings
  checkModulesBindings();
  checkAlgorithmsBindings();
  // check var access permissions
  checkPermissions();
  // check expressions (lint)
  checkExpressions();
  // determine which VIO are assigned to wires
  determineModAlgBoundVIO();
  // determine wich states call wich subroutines
  analyzeSubroutineCalls();
  // analyze variables access 
  determineVariableAndOutputsUsage();
  // analyze instanced algorithms inputs
  analyzeInstancedAlgorithmsInputs();
}

// -------------------------------------------------

std::tuple<t_type_nfo, int> Algorithm::determineVIOTypeWidthAndTableSize(const t_combinational_block_context *bctx, std::string vname,int line) const
{
  t_type_nfo tn;
  tn.base_type   = Int;
  tn.width       = -1;
  int table_size = 0;
  // translate
  vname = translateVIOName(vname, bctx);
  // test if variable
  if (m_VarNames.find(vname) != m_VarNames.end()) {
    tn         = m_Vars[m_VarNames.at(vname)].type_nfo;
    table_size = m_Vars[m_VarNames.at(vname)].table_size;
  } else if (m_InputNames.find(vname) != m_InputNames.end()) {
    tn         = m_Inputs[m_InputNames.at(vname)].type_nfo;
    table_size = m_Inputs[m_InputNames.at(vname)].table_size;
  } else if (m_OutputNames.find(vname) != m_OutputNames.end()) {
    tn         = m_Outputs[m_OutputNames.at(vname)].type_nfo;
    table_size = m_Outputs[m_OutputNames.at(vname)].table_size;
  } else if (m_InOutNames.find(vname) != m_InOutNames.end()) {
    tn         = m_InOuts[m_InOutNames.at(vname)].type_nfo;
    table_size = m_InOuts[m_InOutNames.at(vname)].table_size;
  } else if (vname == ALG_CLOCK) {
    tn         = t_type_nfo(UInt,1);
    table_size = 0;
  } else if (vname == ALG_RESET) {
    tn         = t_type_nfo(UInt,1);
    table_size = 0;
  } else {
    reportError(nullptr, line, "variable '%s' not yet declared", vname.c_str());
  }
  return std::make_tuple(tn, table_size);
}

// -------------------------------------------------

std::tuple<t_type_nfo, int> Algorithm::determineIdentifierTypeWidthAndTableSize(const t_combinational_block_context *bctx, antlr4::tree::TerminalNode *identifier, int line) const
{
  sl_assert(identifier != nullptr);
  std::string vname = identifier->getText();
  return determineVIOTypeWidthAndTableSize(bctx, vname, line);
}

// -------------------------------------------------

t_type_nfo Algorithm::determineIdentifierTypeAndWidth(const t_combinational_block_context *bctx, antlr4::tree::TerminalNode *identifier, int line) const
{
  sl_assert(identifier != nullptr);
  auto tws = determineIdentifierTypeWidthAndTableSize(bctx, identifier, line);
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
    reportError(ioaccess->getSourceInterval(),(int)ioaccess->getStart()->getLine(),
      "'.' access depth limited to one in current version '%s'", base.c_str());
  }
  std::string member = ioaccess->IDENTIFIER()[1]->getText();
  // accessing an algorithm?
  auto A = m_InstancedAlgorithms.find(base);
  if (A != m_InstancedAlgorithms.end()) {
    if (!A->second.algo->isInput(member) && !A->second.algo->isOutput(member)) {
      reportError(ioaccess->getSourceInterval(), (int)ioaccess->getStart()->getLine(),
        "'%s' is neither an input not an output, instance '%s'", member.c_str(), base.c_str());
    }
    if (A->second.algo->isInput(member)) {
      if (A->second.boundinputs.count(member) > 0) {
        reportError(ioaccess->getSourceInterval(), (int)ioaccess->getStart()->getLine(),
          "cannot access bound input '%s' on instance '%s'", member.c_str(), base.c_str());
      }
      return A->second.algo->m_Inputs[A->second.algo->m_InputNames.at(member)].type_nfo;
    } else if (A->second.algo->isOutput(member)) {
      return A->second.algo->m_Outputs[A->second.algo->m_OutputNames.at(member)].type_nfo;
    } else {
      sl_assert(false);
    }
  } else {
    auto G = m_VIOGroups.find(base);
    if (G != m_VIOGroups.end()) {
      verifyMemberGroup(member, G->second, (int)ioaccess->getStart()->getLine());
      // produce the variable name
      std::string vname = base + "_" + member;
      // get width and size
      auto tws = determineVIOTypeWidthAndTableSize(bctx, vname, (int)ioaccess->getStart()->getLine());
      return std::get<0>(tws);
    } else {
      reportError(ioaccess->getSourceInterval(), (int)ioaccess->getStart()->getLine(),
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
    reportError(bfaccess->getSourceInterval(), (int)bfaccess->getStart()->getLine(), "unkown bitfield '%s'", bfaccess->field->getText().c_str());
  }
  // either identifier or ioaccess
  t_type_nfo packed;
  if (bfaccess->idOrIoAccess()->IDENTIFIER() != nullptr) {
    packed = determineIdentifierTypeAndWidth(bctx, bfaccess->idOrIoAccess()->IDENTIFIER(), (int)bfaccess->getStart()->getLine());
  } else {
    packed = determineIOAccessTypeAndWidth(bctx, bfaccess->idOrIoAccess()->ioAccess());
  }
  // get member
  verifyMemberBitfield(bfaccess->member->getText(), F->second, (int)bfaccess->getStart()->getLine());
  pair<t_type_nfo, int> ow = bitfieldMemberTypeAndOffset(F->second, bfaccess->member->getText());
  if (ow.first.width + ow.second > packed.width) {
    reportError(bfaccess->getSourceInterval(), (int)bfaccess->getStart()->getLine(), "bitfield access '%s.%s' is out of bounds", bfaccess->field->getText().c_str(), bfaccess->member->getText().c_str());
  }
  return ow.first;
}

// -------------------------------------------------

t_type_nfo Algorithm::determineBitAccessTypeAndWidth(const t_combinational_block_context *bctx, siliceParser::BitAccessContext *bitaccess) const
{
  sl_assert(bitaccess != nullptr);
  t_type_nfo tn;
  if (bitaccess->IDENTIFIER() != nullptr) {
    tn = determineIdentifierTypeAndWidth(bctx, bitaccess->IDENTIFIER(), (int)bitaccess->getStart()->getLine());
  } else if (bitaccess->tableAccess() != nullptr) {
    tn = determineTableAccessTypeAndWidth(bctx, bitaccess->tableAccess());
  } else {
    tn = determineIOAccessTypeAndWidth(bctx, bitaccess->ioAccess());
  }
  tn.width = std::stoi(bitaccess->num->getText());
  return tn;
}

// -------------------------------------------------

t_type_nfo Algorithm::determineTableAccessTypeAndWidth(const t_combinational_block_context *bctx, siliceParser::TableAccessContext *tblaccess) const
{
  sl_assert(tblaccess != nullptr);
  if (tblaccess->IDENTIFIER() != nullptr) {
    return determineIdentifierTypeAndWidth(bctx, tblaccess->IDENTIFIER(), (int)tblaccess->getStart()->getLine());
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
    } else if (access->bitAccess() != nullptr) {
      return determineBitAccessTypeAndWidth(bctx, access->bitAccess());
    } else if (access->bitfieldAccess() != nullptr) {
      return determineBitfieldAccessTypeAndWidth(bctx, access->bitfieldAccess());
    }
  } else if (identifier) {
    // identifier
    return determineIdentifierTypeAndWidth(bctx, identifier, (int)identifier->getSymbol()->getLine());
  }
  sl_assert(false);
  return t_type_nfo(UInt, 0);
}

// -------------------------------------------------

void Algorithm::writeAlgorithmCall(antlr4::tree::ParseTree *node, std::string prefix, std::ostream& out, const t_algo_nfo& a, siliceParser::ParamListContext* plist, const t_combinational_block_context *bctx, const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const
{
  // check for clock domain crossing
  if (a.instance_clock != m_Clock) {
    reportError(node->getSourceInterval(),(int)plist->getStart()->getLine(),
      "algorithm instance '%s' called accross clock-domain -- not yet supported",
      a.instance_name.c_str());
  }
  // check for call on purely combinational
  if (a.algo->hasNoFSM()) {
    reportError(node->getSourceInterval(), (int)plist->getStart()->getLine(),
      "algorithm instance '%s' called while being purely combinational",
      a.instance_name.c_str());
  }
  // get params
  std::vector<antlr4::tree::ParseTree*> params;
  getParams(plist, params);
  // if params are empty we simply call, otherwise we set the inputs
  if (!params.empty()) {
    if (a.algo->m_Inputs.size() != params.size()) {
      reportError(node->getSourceInterval(), (int)plist->getStart()->getLine(),
        "incorrect number of input parameters in call to algorithm instance '%s'",
        a.instance_name.c_str());
    }
    // set inputs
    int p = 0;
    for (const auto& ins : a.algo->m_Inputs) {
      if (a.boundinputs.count(ins.name) > 0) {
        reportError(node->getSourceInterval(), (int)plist->getStart()->getLine(),
        "algorithm instance '%s' cannot be called with parameters as its input '%s' is bound",
          a.instance_name.c_str(), ins.name.c_str());
      }
      out << FF_D << a.instance_prefix << "_" << ins.name
        << " = " << rewriteExpression(prefix, params[p++], -1 /*cannot be in repeated block*/, bctx, FF_Q, true, dependencies, _ff_usage) 
        << ";" << nxl;
    }
  }
  // restart algorithm (pulse run low)
  out << a.instance_prefix << "_" << ALG_RUN << " = 0;" << nxl;
  /// WARNING: this does not work across clock domains!
}

// -------------------------------------------------

void Algorithm::writeAlgorithmReadback(antlr4::tree::ParseTree *node, std::string prefix, std::ostream& out, const t_algo_nfo& a, siliceParser::AssignListContext* plist, const t_combinational_block_context* bctx, t_vio_ff_usage &_ff_usage) const
{
  // check for pipeline
  if (bctx->pipeline != nullptr) {
    reportError(node->getSourceInterval(), (int)plist->getStart()->getLine(),
      "cannot join algorithm instance from a pipeline");
  }
  // check for clock domain crossing
  if (a.instance_clock != m_Clock) {
    reportError(node->getSourceInterval(), (int)plist->getStart()->getLine(),
     "algorithm instance '%s' joined accross clock-domain -- not yet supported",
      a.instance_name.c_str());
  }
  // check for call on purely combinational
  if (a.algo->hasNoFSM()) {
    reportError(node->getSourceInterval(), (int)plist->getStart()->getLine(),
      "algorithm instance '%s' joined while being purely combinational",
      a.instance_name.c_str());
  }
  // if params are empty we simply wait, otherwise we set the outputs
  if (!plist->assign().empty()) {
    if (a.algo->m_Outputs.size() != plist->assign().size()) {
      reportError(node->getSourceInterval(), (int)plist->getStart()->getLine(),
      "incorrect number of output parameters reading back result from algorithm instance '%s'",
        a.instance_name.c_str());
    }
    // read outputs
    int p = 0;
    for (const auto& outs : a.algo->m_Outputs) {
      if (plist->assign()[p]->access() != nullptr) {
        t_vio_dependencies _;
        writeAccess(prefix, out, true, plist->assign()[p]->access(), -1, bctx, FF_D, _, _ff_usage);
      } else {
        t_vio_dependencies _;
        out << rewriteIdentifier(prefix, plist->assign()[p]->IDENTIFIER()->getText(), bctx, plist->getStart()->getLine(), FF_D, true, _, _ff_usage);
      }
      out << " = " << WIRE << a.instance_prefix << "_" << outs.name << ";" << nxl;
      ++p;
    }
  }
}

// -------------------------------------------------

void Algorithm::writeSubroutineCall(antlr4::tree::ParseTree *node, std::string prefix, std::ostream& out, const t_subroutine_nfo *called, const t_combinational_block_context *bctx, siliceParser::ParamListContext* plist, const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const
{
  if (bctx->pipeline != nullptr) {
    reportError(node->getSourceInterval(), (int)plist->getStart()->getLine(),
      "cannot call a subroutine from a pipeline");
  }
  std::vector<antlr4::tree::ParseTree*> params;
  getParams(plist, params);
  // check num parameters
  if (called->inputs.size() != params.size()) {
    reportError(node->getSourceInterval(), (int)plist->getStart()->getLine(),
      "incorrect number of input parameters in call to subroutine '%s'",
      called->name.c_str());
  }
  // set inputs
  int p = 0;
  for (const auto& ins : called->inputs) {
    // skip inputs which are not used
    const auto& info = m_Vars[m_VarNames.at(called->vios.at(ins))];
    if (info.access == e_WriteOnly) {
      p++;
      continue;
    }
    out << FF_D << prefix << called->vios.at(ins)
      << " = " << rewriteExpression(prefix, params[p++], -1 /*cannot be in repeated block*/, bctx, FF_Q, true, dependencies, _ff_usage)
      << ';' << nxl;
  }
}

// -------------------------------------------------

void Algorithm::writeSubroutineReadback(antlr4::tree::ParseTree *node, std::string prefix, std::ostream& out, const t_subroutine_nfo* called, const t_combinational_block_context* bctx, siliceParser::AssignListContext* plist, t_vio_ff_usage &_ff_usage) const
{
  if (bctx->pipeline != nullptr) {
    reportError(node->getSourceInterval(), (int)plist->getStart()->getLine(),
    "cannot join a subroutine from a pipeline");
  }
  // if params are empty we simply wait, otherwise we set the outputs
  if (called->outputs.size() != plist->assign().size()) {
    reportError(node->getSourceInterval(), (int)plist->getStart()->getLine(),
    "incorrect number of output parameters reading back result from subroutine '%s'",
      called->name.c_str());
  }
  // read outputs (reading from FF_D or FF_Q should be equivalent since we just cycled the state machine)
  int p = 0;
  for (const auto& outs : called->outputs) {
    if (plist->assign()[p]->access() != nullptr) {
      t_vio_dependencies _;
      writeAccess(prefix, out, true, plist->assign()[p]->access(), -1, bctx, FF_D, _, _ff_usage);
    } else {
      t_vio_dependencies _;
      out << rewriteIdentifier(prefix, plist->assign()[p]->IDENTIFIER()->getText(), bctx, plist->getStart()->getLine(), FF_D, true, _, _ff_usage);
    }
    out << " = " << FF_D << prefix << called->vios.at(outs) << ';' << nxl;
    ++p;
  }
}

// -------------------------------------------------

std::tuple<t_type_nfo, int> Algorithm::writeIOAccess(
  std::string prefix, std::ostream& out, bool assigning, siliceParser::IoAccessContext* ioaccess,
  int __id, const t_combinational_block_context* bctx, string ff,
  const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const
{
  std::string base = ioaccess->base->getText();
  base = translateVIOName(base, bctx);
  if (ioaccess->IDENTIFIER().size() != 2) {
    reportError(ioaccess->getSourceInterval(), (int)ioaccess->getStart()->getLine(),
      "'.' access depth limited to one in current version '%s'", base.c_str());
  }
  std::string member = ioaccess->IDENTIFIER()[1]->getText();
  // find algorithm
  auto A = m_InstancedAlgorithms.find(base);
  if (A != m_InstancedAlgorithms.end()) {
    if (!A->second.algo->isInput(member) && !A->second.algo->isOutput(member)) {
      reportError(ioaccess->getSourceInterval(), (int)ioaccess->getStart()->getLine(),
        "'%s' is neither an input not an output, instance '%s'", member.c_str(), base.c_str());
    }
    if (assigning && !A->second.algo->isInput(member)) {
      reportError(ioaccess->getSourceInterval(), (int)ioaccess->getStart()->getLine(),
        "cannot write to algorithm output '%s', instance '%s'", member.c_str(), base.c_str());
    }
    if (!assigning && !A->second.algo->isOutput(member)) {
      reportError(ioaccess->getSourceInterval(), (int)ioaccess->getStart()->getLine(),
        "cannot read from algorithm input '%s', instance '%s'", member.c_str(), base.c_str());
    }
    if (A->second.algo->isInput(member)) {
      if (A->second.boundinputs.count(member) > 0) {
        reportError(ioaccess->getSourceInterval(), (int)ioaccess->getStart()->getLine(),
        "cannot access bound input '%s' on instance '%s'", member.c_str(), base.c_str());
      }
      if (assigning) {
        out << FF_D; // algorithm input
      } else {
        sl_assert(false); // cannot read from input
      }
      out << A->second.instance_prefix << "_" << member;
      // return A->second.algo->m_Inputs[A->second.algo->m_InputNames.at(member)].width;
      return A->second.algo->determineVIOTypeWidthAndTableSize(bctx, member, (int)ioaccess->getStart()->getLine());
    } else if (A->second.algo->isOutput(member)) {
      out << WIRE << A->second.instance_prefix << "_" << member;
      // return A->second.algo->m_Outputs[A->second.algo->m_OutputNames.at(member)].width;
      return A->second.algo->determineVIOTypeWidthAndTableSize(bctx, member, (int)ioaccess->getStart()->getLine());
    } else {
      sl_assert(false);
    }
  } else {
    auto G = m_VIOGroups.find(base);
    if (G != m_VIOGroups.end()) {
      verifyMemberGroup(member, G->second, (int)ioaccess->getStart()->getLine());
      // produce the variable name
      std::string vname = base + "_" + member;
      // write
      out << rewriteIdentifier(prefix, vname, bctx, (int)ioaccess->getStart()->getLine(), assigning ? FF_D : ff, !assigning, dependencies, _ff_usage);
      return determineVIOTypeWidthAndTableSize(bctx, vname, (int)ioaccess->getStart()->getLine());
    } else {
      reportError(ioaccess->getSourceInterval(), (int)ioaccess->getStart()->getLine(),
        "cannot find accessed base.member '%s.%s'", base.c_str(), member.c_str());
    }
  }
  sl_assert(false);
  return make_tuple(t_type_nfo(UInt, 0), 0);
}

// -------------------------------------------------

void Algorithm::writeTableAccess(
  std::string prefix, std::ostream& out, bool assigning,
  siliceParser::TableAccessContext* tblaccess, 
  int __id, const t_combinational_block_context *bctx, string ff,
  const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const
{
  if (tblaccess->ioAccess() != nullptr) {
    auto tws = writeIOAccess(prefix, out, assigning, tblaccess->ioAccess(), __id, bctx, ff, dependencies, _ff_usage);
    if (get<1>(tws) == 0) {
      reportError(tblaccess->ioAccess()->IDENTIFIER().back()->getSymbol(), (int)tblaccess->getStart()->getLine(), "trying to access a non table as a table");
    }
    out << "[" << rewriteExpression(prefix, tblaccess->expression_0(), __id, bctx, FF_Q, true, dependencies, _ff_usage) << ']';
  } else {
    sl_assert(tblaccess->IDENTIFIER() != nullptr);
    std::string vname = tblaccess->IDENTIFIER()->getText();
    out << rewriteIdentifier(prefix, vname, bctx, tblaccess->getStart()->getLine(), assigning ? FF_D : ff, !assigning, dependencies, _ff_usage);
    // get width
    auto tws = determineIdentifierTypeWidthAndTableSize(bctx, tblaccess->IDENTIFIER(), (int)tblaccess->getStart()->getLine());
    if (get<1>(tws) == 0) {
      reportError(tblaccess->IDENTIFIER()->getSymbol(), (int)tblaccess->getStart()->getLine(), "trying to access a non table as a table");
    }
    // TODO: if the expression can be evaluated at compile time, we could check for access validity using table_size
    out << "[" << rewriteExpression(prefix, tblaccess->expression_0(), __id, bctx, FF_Q, true, dependencies, _ff_usage) << ']';
  }
}

// -------------------------------------------------

void Algorithm::writeBitfieldAccess(std::string prefix, std::ostream& out, bool assigning, siliceParser::BitfieldAccessContext* bfaccess, 
  int __id, const t_combinational_block_context* bctx, string ff,
  const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const
{
  // find field definition
  auto F = m_KnownBitFields.find(bfaccess->field->getText());
  if (F == m_KnownBitFields.end()) {
    reportError(bfaccess->getSourceInterval(), (int)bfaccess->getStart()->getLine(), "unkown bitfield '%s'", bfaccess->field->getText().c_str());
  }
  verifyMemberBitfield(bfaccess->member->getText(), F->second, (int)bfaccess->getStart()->getLine());
  pair<t_type_nfo, int> ow = bitfieldMemberTypeAndOffset(F->second, bfaccess->member->getText());
  sl_assert(ow.first.width > -1); // should never happen as member is checked before
  if (ow.first.base_type == Int) {
    out << "$signed(";
  }
  if (bfaccess->idOrIoAccess()->ioAccess() != nullptr) {
    writeIOAccess(prefix, out, assigning, bfaccess->idOrIoAccess()->ioAccess(), __id, bctx, ff, dependencies, _ff_usage);
  } else {
    sl_assert(bfaccess->idOrIoAccess()->IDENTIFIER() != nullptr);
    out << rewriteIdentifier(prefix, bfaccess->idOrIoAccess()->IDENTIFIER()->getText(), bctx, 
      bfaccess->idOrIoAccess()->getStart()->getLine(), assigning ? FF_D : ff, !assigning, dependencies, _ff_usage);
  }
  out << '[' << ow.second << "+:" << ow.first.width << ']';
  if (ow.first.base_type == Int) {
    out << ")";
  }
}

// -------------------------------------------------

void Algorithm::writeBitAccess(std::string prefix, std::ostream& out, bool assigning, siliceParser::BitAccessContext* bitaccess, 
  int __id, const t_combinational_block_context* bctx, string ff,
  const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const
{
  // TODO: check access validity
  if (bitaccess->ioAccess() != nullptr) {
    writeIOAccess(prefix, out, assigning, bitaccess->ioAccess(), __id, bctx, ff, dependencies, _ff_usage);
  } else if (bitaccess->tableAccess() != nullptr) {
    writeTableAccess(prefix, out, assigning, bitaccess->tableAccess(), __id, bctx, ff, dependencies, _ff_usage);
  } else {
    sl_assert(bitaccess->IDENTIFIER() != nullptr);
    out << rewriteIdentifier(prefix, bitaccess->IDENTIFIER()->getText(), bctx, 
      bitaccess->getStart()->getLine(), assigning ? FF_D : ff, !assigning, dependencies, _ff_usage);
  }
  out << '[' << rewriteExpression(prefix, bitaccess->first, __id, bctx, FF_Q, true, dependencies, _ff_usage) << "+:" << bitaccess->num->getText() << ']';
  if (assigning) {
    // This is a bit access. We assume it is partial (could be checked if const).
    // Thus the variable is likely only partially written and to be safe we tag
    // it as Q since other bits are likely read later in the execution flow.
    // This is a conservative assumption. A bit-per-bit analysis could be envisioned, 
    // but for lack of it we have no other choice here to avoid generating wrong code.
    // See also issue #54.
    std::string var = determineAccessedVar(bitaccess, bctx);
    updateFFUsage(e_Q, true, _ff_usage.ff_usage[var]);
  }
}

// -------------------------------------------------

void Algorithm::writeAccess(std::string prefix, std::ostream& out, bool assigning, siliceParser::AccessContext* access, 
  int __id, const t_combinational_block_context* bctx, string ff,
  const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const
{
  if (access->ioAccess() != nullptr) {
    writeIOAccess(prefix, out, assigning, access->ioAccess(), __id, bctx, ff, dependencies, _ff_usage);
  } else if (access->tableAccess() != nullptr) {
    writeTableAccess(prefix, out, assigning, access->tableAccess(), __id, bctx, ff, dependencies, _ff_usage);
  } else if (access->bitAccess() != nullptr) {
    writeBitAccess(prefix, out, assigning, access->bitAccess(), __id, bctx, ff, dependencies, _ff_usage);
  } else if (access->bitfieldAccess() != nullptr) {
    writeBitfieldAccess(prefix, out, assigning, access->bitfieldAccess(), __id, bctx, ff, dependencies, _ff_usage);
  }
}

// -------------------------------------------------

void Algorithm::writeAssignement(std::string prefix, std::ostream& out,
  const t_instr_nfo& a,
  siliceParser::AccessContext *access,
  antlr4::tree::TerminalNode* identifier,
  siliceParser::Expression_0Context *expression_0,
  const t_combinational_block_context *bctx,
  string ff, const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const
{
  if (access) {
    // table, output or bits
    writeAccess(prefix, out, true, access, a.__id, bctx, ff, dependencies, _ff_usage);
  } else {
    sl_assert(identifier != nullptr);
    // variable
    if (isInput(identifier->getText())) {
      reportError(a.instr->getSourceInterval(), (int)identifier->getSymbol()->getLine(),
        "cannot assign a value to an input of the algorithm, input '%s'",
        identifier->getText().c_str());
    }
    out << rewriteIdentifier(prefix, identifier->getText(), bctx, identifier->getSymbol()->getLine(), FF_D, false, dependencies, _ff_usage);
  }
  out << " = " + rewriteExpression(prefix, expression_0, a.__id, bctx, ff, true, dependencies, _ff_usage);
  out << ';' << nxl;

} 

// -------------------------------------------------

void Algorithm::writeWireAssignements(
  std::string prefix, std::ostream &out,  
  t_vio_dependencies& _dependencies, t_vio_ff_usage &_ff_usage) const
{
  t_combinational_block_context empty;
  for (const auto &a : m_WireAssignments) {
    auto alw = dynamic_cast<siliceParser::AlwaysAssignedContext *>(a.second.instr);
    sl_assert(alw != nullptr);
    sl_assert(alw->IDENTIFIER() != nullptr);
    // -> determine assigned var
    string var = translateVIOName(alw->IDENTIFIER()->getText(), &empty);
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
    bool d_or_q = (alw->ALWSASSIGNDBL() == nullptr);
    out << "assign ";
    writeAssignement(prefix, out, a.second, alw->access(), alw->IDENTIFIER(), alw->expression_0(), &empty,
      d_or_q ? FF_D : FF_Q,
      _dependencies, _ff_usage);    
    // update dependencies
    t_vio_dependencies no_dependencies = _dependencies;
    updateAndCheckDependencies(_dependencies, a.second.instr, &empty);
    // we take the opportunity to check that if the wire depends on other wires, they are either all := or all ::=
    // mixing these two is forbidden, as this quickly leads to confusion without real benefits
    for (const auto &d : _dependencies.dependencies.at(var)) {
      // is this dependency a wire?
      auto W = m_WireAssignments.find(d);
      if (W != m_WireAssignments.end()) {
        auto w_alw    = dynamic_cast<siliceParser::AlwaysAssignedContext *>(W->second.instr);
        bool w_d_or_q = (w_alw->ALWSASSIGNDBL() == nullptr);
        if (d_or_q ^ w_d_or_q) {
          reportError(alw->getSourceInterval(), (int)alw->getStart()->getLine(), 
            "inconsistent use of ::= and := between bound expressions (with '%s')",d.c_str());
        }
      }
      // update usage of dependencies to q
      // NOTE: could be done only if wire is used ...
      updateFFUsage(e_Q, true, _ff_usage.ff_usage[d]);
    }
    if (!d_or_q) {
      // ignore dependencies if reading from Q: we can ignore them safely
      // as the wire does not contribute to create combinational cycles
      _dependencies = no_dependencies;
    }
  }
  out << endl;
}

// -------------------------------------------------

void Algorithm::writeVarFlipFlopInit(std::string prefix, std::ostream& out, const t_var_nfo& v) const
{
  if (!v.do_not_initialize) {
    if (v.table_size == 0) {
      out << FF_Q << prefix << v.name << " <= " << v.init_values[0] << ';' << endl;
    } else {
      ForIndex(i,v.init_values.size()) {
        out << FF_Q << prefix << v.name << "[" << i << "] <= " << v.init_values[i] << ';' << endl;
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::writeVarFlipFlopUpdate(std::string prefix, std::ostream& out, const t_var_nfo& v) const
{
  if (v.table_size == 0) {
    out << FF_Q << prefix << v.name << " <= " << FF_D << prefix << v.name << ';' << endl;
  } else {
    ForIndex(i, v.init_values.size()) {
      out << FF_Q << prefix << v.name << "[" << i << "] <= " << FF_D << prefix << v.name << "[" << i << "];" << endl;
    }
  }
}

// -------------------------------------------------

std::string Algorithm::varBitRange(const t_var_nfo& v) const
{
  if (v.type_nfo.base_type == Parameterized) {
    string str = v.name;
    std::transform(str.begin(), str.end(), str.begin(),
      [](unsigned char c) -> unsigned char { return std::toupper(c); });
    str = str + "_WIDTH-1";
    return "[" + str + ":0]";
  } else {
    return "[" + std::to_string(v.type_nfo.width - 1) + ":0]";
  }
}

// -------------------------------------------------

std::string Algorithm::varBitWidth(const t_var_nfo &v) const
{
  if (v.type_nfo.base_type == Parameterized) {
    string str = v.name;
    std::transform(str.begin(), str.end(), str.begin(),
      [](unsigned char c) -> unsigned char { return std::toupper(c); });
    return str + "_WIDTH";
  } else {
    return std::to_string(v.type_nfo.width);
  }
}

// -------------------------------------------------

std::string Algorithm::typeString(const t_var_nfo& v) const
{
  sl_assert(v.type_nfo.base_type != Parameterized);
  return typeString(v.type_nfo.base_type);
}

// -------------------------------------------------

void Algorithm::writeVerilogDeclaration(std::ostream &out, std::string base, const t_var_nfo &v, std::string postfix) const
{
  if (v.type_nfo.base_type == Parameterized) {
    out << base << " " << typeString(UInt) << " " << varBitRange(v) << " " << postfix << ';' << endl;
  } else {
    out << base << " " << typeString(v) << " " << varBitRange(v) << " " << postfix << ';' << endl;
  }
}

// -------------------------------------------------

std::string Algorithm::typeString(e_Type type) const
{
  if (type == Int) {
    return "signed";
  }
  return "";
}

// -------------------------------------------------

void Algorithm::writeConstDeclarations(std::string prefix, std::ostream& out) const
{
  for (const auto& v : m_Vars) {
    if (v.usage != e_Const) continue;
    if (v.table_size == 0) {
      writeVerilogDeclaration(out, "wire", v, string(FF_CST) + prefix + v.name);
      // out << "wire " << typeString(v) << " " << varBitRange(v) << " " << FF_CST << prefix << v.name << ';' << nxl;
    } else {
      writeVerilogDeclaration(out, "wire", v, string(FF_CST) + prefix + v.name + '[' + std::to_string(v.table_size - 1) + ":0]");
      // out << "wire " << typeString(v) << " " << varBitRange(v) << " " << FF_CST << prefix << v.name << '[' << v.table_size - 1 << ":0]" << ';' << nxl;
    }
    if (!v.do_not_initialize) {
      if (v.table_size == 0) {
        out << "assign " << FF_CST << prefix << v.name << " = " << v.init_values[0] << ';' << nxl;
      } else {
        int width = v.type_nfo.width;
        ForIndex(i, v.table_size) {
          out << "assign " << FF_CST << prefix << v.name << '[' << i << ']' << " = " << v.init_values[i] << ';' << nxl;
        }
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::writeTempDeclarations(std::string prefix, std::ostream& out) const
{
  for (const auto& v : m_Vars) {
    if (v.usage != e_Temporary) continue;
    if (v.table_size == 0) {
      writeVerilogDeclaration(out, "reg", v, string(FF_TMP) + prefix + v.name);
      // out << "reg " << typeString(v) << " " << varBitRange(v) << " " << FF_TMP << prefix << v.name << ';' << nxl;
    } else {
      writeVerilogDeclaration(out, "reg", v, string(FF_TMP) + prefix + v.name + '[' + std::to_string(v.table_size - 1) + ":0]");
      // out << "reg " << typeString(v) << " " << varBitRange(v) << " " << FF_TMP << prefix << v.name << '[' << v.table_size-1 << ":0]" << ';' << nxl;
    }
  }
  for (const auto &v : m_Outputs) {
    if (v.usage != e_Temporary) continue;
    out << "reg " << typeString(v) << " " << varBitRange(v) << " " << FF_TMP << prefix << v.name << ';' << nxl;
  }
}

// -------------------------------------------------

void Algorithm::writeWireDeclarations(std::string prefix, std::ostream& out) const
{
  for (const auto& v : m_Vars) {
    if ((v.usage == e_Bound && v.access == e_ReadWriteBinded) || v.usage == e_Wire) {
      // skip if not used
      if (v.access == e_NotAccessed) { continue; }
      if (v.table_size == 0) {
        writeVerilogDeclaration(out, "wire", v, string(WIRE) + prefix + v.name);
        //out << "wire " << typeString(v) << " " << varBitRange(v) << " " << WIRE << prefix << v.name << ';' << nxl;
      } else {
        writeVerilogDeclaration(out, "wire", v, string(WIRE) + prefix + v.name + '[' + std::to_string(v.table_size - 1) + ":0]");
        //out << "wire " << typeString(v) << " " << varBitRange(v) << " " << WIRE << prefix << v.name << '[' << v.table_size - 1 << ":0]" << ';' << nxl;
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::writeFlipFlopDeclarations(std::string prefix, std::ostream& out) const
{
  out << nxl;
  // flip-flops for vars
  for (const auto& v : m_Vars) {
    if (v.usage != e_FlipFlop) continue;
    if (v.table_size == 0) {
      writeVerilogDeclaration(out, "reg", v, string(FF_D) + prefix + v.name);
      //out << "reg " << typeString(v) << " " << varBitRange(v) << " ";
      //out << FF_D << prefix << v.name << ';' << nxl;
      writeVerilogDeclaration(out, (v.attribs.empty() ? "" : (v.attribs + "\n")) + "reg", v, string(FF_Q) + prefix + v.name);
      //if (!v.attribs.empty()) {
      //  out << v.attribs << nxl;
      //}
      //out << "reg " << typeString(v) << " " << varBitRange(v) << " ";
      //out << FF_Q << prefix << v.name << ';' << nxl;
    } else {
      writeVerilogDeclaration(out, "reg", v, string(FF_D) + prefix + v.name + '[' + std::to_string(v.table_size - 1) + ":0]");
      //out << "reg " << typeString(v) << " " << varBitRange(v) << " ";
      //out << FF_D << prefix << v.name << '[' << v.table_size-1 << ";" << nxl;
      writeVerilogDeclaration(out, (v.attribs.empty() ? "" : (v.attribs + "\n")) + "reg", v, string(FF_Q) + prefix + v.name + '[' + std::to_string(v.table_size - 1) + ":0]");
      //if (!v.attribs.empty()) {
      //  out << v.attribs << nxl;
      //}
      //out << "reg " << typeString(v) << " " << varBitRange(v) << " ";
      //out << FF_Q << prefix << v.name << '[' << v.table_size - 1 << ";" << nxl;
    }
  }
  // flip-flops for outputs
  for (const auto& v : m_Outputs) {
    if (v.usage != e_FlipFlop) continue;
    writeVerilogDeclaration(out, "reg", v, string(FF_D) + prefix + v.name + ',' + string(FF_Q) + prefix + v.name);
    //out << "reg " << typeString(v) << " " << varBitRange(v) << " ";
    //out << FF_D << prefix << v.name << ',' << FF_Q << prefix << v.name << ';' << nxl;
  }
  // flip-flops for algorithm inputs that are not bound
  for (const auto& iaiordr : m_InstancedAlgorithmsInDeclOrder) {
    const auto &ia = m_InstancedAlgorithms.at(iaiordr);
    for (const auto &is : ia.algo->m_Inputs) {
      if (ia.boundinputs.count(is.name) == 0) {
        writeVerilogDeclaration(out, "reg", is, string(FF_D) + ia.instance_prefix + '_' + is.name + ',' + string(FF_Q) + ia.instance_prefix + '_' + is.name);
        //out << "reg " << typeString(is) << " " << varBitRange(is) << " ";
        //out << FF_D << ia.instance_prefix << '_' << is.name << ',' << FF_Q << ia.instance_prefix << '_' << is.name << ';' << nxl;
      }
    }
  }
  // state machine index
  if (!hasNoFSM()) {
    if (!m_OneHot) {
      out << "reg  [" << stateWidth() - 1 << ":0] " FF_D << prefix << ALG_IDX "," FF_Q << prefix << ALG_IDX << ';' << nxl;
    } else {
      out << "reg  [" << maxState() - 1 << ":0] " FF_D << prefix << ALG_IDX "," FF_Q << prefix << ALG_IDX << ';' << nxl;
    }
    // sub-state indices (one-hot)
    for (auto b : m_Blocks) {
      if (b->num_sub_states > 1) {
        out << "reg  [" << stateWidth(b->num_sub_states) - 1 << ":0] " FF_D << prefix << b->block_name << '_' << ALG_IDX "," FF_Q << prefix << b->block_name << '_' << ALG_IDX << ';' << nxl;
      }
    }
  }
  // state machine caller id (subroutine)
  if (!doesNotCallSubroutines()) {
    out << "reg  [" << (stateWidth() - 1) << ":0] " FF_D << prefix << ALG_CALLER << "," FF_Q << prefix << ALG_CALLER << ";" << nxl;
    // per-subroutine caller id backup (subroutine making nested calls)
    for (auto sub : m_Subroutines) {
      if (sub.second->contains_calls) {
        out << "reg  [" << (stateWidth() - 1) << ":0] " FF_D << prefix << sub.second->name << "_" << ALG_CALLER << "," FF_Q << prefix << sub.second->name << "_" << ALG_CALLER << ";" << nxl;
      }
    }
  }
  // state machine run for instanced algorithms
  for (const auto& iaiordr : m_InstancedAlgorithmsInDeclOrder) {
    const auto &ia = m_InstancedAlgorithms.at(iaiordr);
    // check for call on purely combinational
    if (!ia.algo->hasNoFSM()) {
      out << "reg  " << ia.instance_prefix + "_" ALG_RUN << ';' << nxl;
    }
  }
}

// -------------------------------------------------

void Algorithm::writeFlipFlops(std::string prefix, std::ostream& out) const
{
  // output flip-flop init and update on clock
  out << nxl;
  std::string clock = m_Clock;
  if (m_Clock != ALG_CLOCK) {
    // in this case, clock has to be bound to a module/algorithm output
    /// TODO: is this over-constrained? could it also be a variable?
    auto C = m_VIOBoundToModAlgOutputs.find(m_Clock);
    if (C == m_VIOBoundToModAlgOutputs.end()) {
      reportError(nullptr,-1,"algorithm '%s', clock is not bound to a module or algorithm output",m_Name.c_str());
    }
    clock = C->second;
  }

  out << "always @(posedge " << clock << ") begin" << nxl;

  /// init on hardware reset
  if (!requiresNoReset()) {
    std::string reset = m_Reset;
    if (m_Reset != ALG_RESET) {
      // in this case, reset has to be bound to a module/algorithm output
      /// TODO: is this over-constrained? could it also be a variable?
      auto R = m_VIOBoundToModAlgOutputs.find(m_Reset);
      if (R == m_VIOBoundToModAlgOutputs.end()) {
        reportError(nullptr, -1, "algorithm '%s', reset is not bound to a module or algorithm output", m_Name.c_str());
      }
      reset = R->second;
    }
    out << "  if (" << reset;
    if (!hasNoFSM()) {
      out << " || !in_run";
    }
    out << ") begin" << nxl;
    for (const auto &v : m_Vars) {
      if (v.usage != e_FlipFlop) continue;
      writeVarFlipFlopInit(prefix, out, v);
    }
    // state machine 
    if (!hasNoFSM()) {
      // -> on reset
      out << "  if (" << reset << ") begin" << nxl;
      if (!m_AutoRun) {
        // no autorun: jump to halt state
        out << FF_Q << prefix << ALG_IDX   " <= " << toFSMState(terminationState()) << ";" << nxl;
      } else {
        // autorun: jump to first state
        out << FF_Q << prefix << ALG_IDX   " <= " << toFSMState(entryState()) << ";" << nxl;
      }
      // sub-states indices
      for (auto b : m_Blocks) {
        if (b->num_sub_states > 1) {
          out << FF_Q << prefix << b->block_name << '_' << ALG_IDX   " <= 0;" << nxl;
        }
      }
      out << "end else begin" << nxl;
      // -> on restart, jump to first state
      out << FF_Q << prefix << ALG_IDX   " <= " << toFSMState(entryState()) << ";" << nxl;
      out << "end" << nxl;
    }
    /// updates on clockpos
    out << "  end else begin" << nxl;
  }
  for (const auto& v : m_Vars) {
    if (v.usage != e_FlipFlop) continue;
    writeVarFlipFlopUpdate(prefix, out, v);
  }
  if (!hasNoFSM()) {
    // state machine index
    out << FF_Q << prefix << ALG_IDX " <= " FF_D << prefix << ALG_IDX << ';' << nxl;
    // sub-states indices
    for (auto b : m_Blocks) {
      if (b->num_sub_states > 1) {
        out << FF_Q << prefix << b->block_name << '_' << ALG_IDX " <= " FF_D << prefix << b->block_name << '_' << ALG_IDX << ';' << nxl;
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
  if (!requiresNoReset()) {
    out << "  end" << nxl;
  }
  // update output flip-flops
  for (const auto &v : m_Outputs) {
    if (v.usage != e_FlipFlop) continue;
    writeVarFlipFlopUpdate(prefix, out, v);
  }
  // update instanced algorithms input flip-flops
  for (const auto& iaiordr : m_InstancedAlgorithmsInDeclOrder) {
    const auto &ia = m_InstancedAlgorithms.at(iaiordr);
    for (const auto &is : ia.algo->m_Inputs) {
      if (ia.boundinputs.count(is.name) == 0) {
        writeVarFlipFlopUpdate(ia.instance_prefix + '_', out, is);
      }
    }
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

void Algorithm::writeCombinationalAlwaysPre(std::string prefix, std::ostream& out, t_vio_dependencies& _always_dependencies, t_vio_ff_usage &_ff_usage) const
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
  for (const auto& iaiordr : m_InstancedAlgorithmsInDeclOrder) {
    const auto &ia = m_InstancedAlgorithms.at(iaiordr);
    for (const auto &is : ia.algo->m_Inputs) {
      if (ia.boundinputs.count(is.name) == 0) {
        writeVarFlipFlopCombinationalUpdate(ia.instance_prefix + '_', out, is);
      }
    }
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
  for (const auto& iaiordr : m_InstancedAlgorithmsInDeclOrder) {
    const auto &ia = m_InstancedAlgorithms.at(iaiordr);
    if (!ia.algo->hasNoFSM()) {
      out << ia.instance_prefix + "_" ALG_RUN " = 1;" << nxl;
    }
  }
  // instanced modules input/output bindings with wires
  // NOTE: could this be done with assignements (see Algorithm::writeAsModule) ?
  for (auto im : m_InstancedModules) {
    for (auto b : im.second.bindings) {
      if (b.dir == e_Right) { // output
        if (m_VarNames.find(bindingRightIdentifier(b)) != m_VarNames.end()) {
          // bound to variable, the variable is replaced by the output wire
          auto usage = m_Vars.at(m_VarNames.at(bindingRightIdentifier(b))).usage;
          sl_assert(usage == e_Bound);
        } else if (m_OutputNames.find(bindingRightIdentifier(b)) != m_OutputNames.end()) {
          // bound to an algorithm output
          auto usage = m_Outputs.at(m_OutputNames.at(bindingRightIdentifier(b))).usage;
          if (usage == e_FlipFlop) {
            out << FF_D << prefix + bindingRightIdentifier(b) + " = " + WIRE + im.second.instance_prefix + "_" + b.left << ';' << nxl;
          }
        }
      }
    }
  }
  // instanced algorithms input/output bindings with wires
  // NOTE: could this be done with assignements (see Algorithm::writeAsModule) ?
  for (const auto& iaiordr : m_InstancedAlgorithmsInDeclOrder) {
    const auto &ia = m_InstancedAlgorithms.at(iaiordr);
    for (auto b : ia.bindings) {
      if (b.dir == e_Right) { // output
        if (m_VarNames.find(bindingRightIdentifier(b)) != m_VarNames.end()) {
          // bound to variable, the variable is replaced by the output wire
          auto usage = m_Vars.at(m_VarNames.at(bindingRightIdentifier(b))).usage;
          sl_assert(usage == e_Bound);
        } else if (m_OutputNames.find(bindingRightIdentifier(b)) != m_OutputNames.end()) {
          // bound to an algorithm output
          auto usage = m_Outputs.at(m_OutputNames.at(bindingRightIdentifier(b))).usage;
          if (usage == e_FlipFlop) {
            // the output is a flip-flop, copy from the wire
            out << FF_D << prefix + bindingRightIdentifier(b) + " = " + WIRE + ia.instance_prefix + "_" + b.left << ';' << nxl;
          }
          // else, the output is replaced by the wire
        }
      }
    }
  }
  // reset temp variables (to ensure no latch is created)
  for (const auto &v : m_Vars) {
    if (v.usage != e_Temporary) continue;
    sl_assert(v.table_size == 0);
    out << FF_TMP << prefix << v.name << " = 0;" << nxl;
  }
  for (const auto &v : m_Outputs) {
    if (v.usage != e_Temporary) continue;
    out << FF_TMP << prefix << v.name << " = 0;" << nxl;
  }
  // always block
  std::queue<size_t> q;
  writeStatelessBlockGraph(prefix, out, &m_AlwaysPre, nullptr, q, _always_dependencies, _ff_usage);
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

void Algorithm::writeCombinationalStates(std::string prefix, std::ostream &out, const t_vio_dependencies &always_dependencies, t_vio_ff_usage &_ff_usage) const
{
  vector<t_vio_ff_usage> ff_usages;
  unordered_set<size_t>  produced;
  queue<size_t>          q;
  q.push(0); // starts at 0
  // states
  if (!m_OneHot) {
    out << "case (" << FF_Q << prefix << ALG_IDX << ")" << nxl;
  } else {
    out << "(* parallel_case, full_case *)" << endl;
    out << "case (1'b1)" << endl;
  }
  // track per-ff state usage
  std::unordered_map<std::string, std::pair<int, int> >  ff_usage_counts;
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
      out << toFSMState(b->state_id) << ": begin" << endl;
    } else {
      out << FF_Q << prefix << ALG_IDX << '[' << b->state_id << "]: begin" << endl;
    }
    // if state contains sub-state
    if (b->num_sub_states > 1) {
      // by default stay in this state
      out << FF_D << prefix << ALG_IDX << " = " << b->state_id << ';' << endl;
      // produce a local one-hot FSM for the sequence
      // out << "(* parallel_case, full_case *)" << endl;
      // out << "case (1'b1)" << endl;
      out << "case (" << FF_Q << prefix << b->block_name << '_' << ALG_IDX << ")" << endl;
      const t_combinational_block *cur = b;
      int sanity = 0;
      while (cur) {
        // write sub-state
        // -> case value
        //out << FF_Q << prefix << b->block_name << '_' << ALG_IDX << '[' << cur->sub_state_id << ']'
        out << cur->sub_state_id
            << ": begin" << endl;
        // -> track dependencies, starting with those of always block
        t_vio_dependencies depds = always_dependencies;
        // -> write block instructions
        ff_usages.push_back(_ff_usage);
        writeStatelessBlockGraph(prefix, out, cur, nullptr, q, depds, ff_usages.back());
        // -> goto next
        if (cur->sub_state_id == b->num_sub_states-1) { 
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
        out << ';' << endl;
        // -> close state
        out << "end" << endl;
        // -> track states ff usage
        for (auto ff : ff_usages.back().ff_usage) {
          ff_usage_counts[ff.first].first += ((ff.second & e_Q) ? 1 : 0);
          ff_usage_counts[ff.first].second += ((ff.second & e_D) ? 1 : 0);
        }
        // keep going
        std::set<t_combinational_block*> leaves;
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
      out << "default: begin end" << endl; // -> should never be reached
      out << "endcase" << endl;
    } else {
      // track dependencies, starting with those of always block
      t_vio_dependencies depds = always_dependencies;
      // write block instructions
      ff_usages.push_back(_ff_usage);
      writeStatelessBlockGraph(prefix, out, b, nullptr, q, depds, ff_usages.back());
      // track states ff usage
      for (auto ff : ff_usages.back().ff_usage) {
        ff_usage_counts[ff.first].first += ((ff.second & e_Q) ? 1 : 0);
        ff_usage_counts[ff.first].second += ((ff.second & e_D) ? 1 : 0);
      }
    }
    // close state
    out << "end" << endl;
  }
  // report on per-ff state use
  if (0) {
    std::cerr << "------ flip-flop per state usage ------" << nxl;
    for (auto cnt : ff_usage_counts) {
      std::cerr << setw(30) << cnt.first << " " << setw(30) << sprint("R:%03d W:%03d", cnt.second.first, cnt.second.second) << nxl;
    }
  }
  // combine all ff usages
  combineFFUsageInto(_ff_usage, ff_usages, _ff_usage);
  // initiate termination sequence
  // -> termination state
  {
    out << toFSMState(terminationState()) << ": begin // end of " << m_Name << nxl;
    out << "end" << nxl;
  }
  // default: internal error, should never happen
  {
    out << "default: begin " << nxl;
    out << FF_D << prefix << ALG_IDX " = " << toFSMState(terminationState()) << ";" << nxl;
    out << " end" << nxl;
  }
  out << "endcase" << nxl;
}

// -------------------------------------------------

void Algorithm::writeBlock(std::string prefix, std::ostream &out, const t_combinational_block *block, t_vio_dependencies &_dependencies, t_vio_ff_usage &_ff_usage) const
{
  out << "// " << block->block_name;
  if (block->context.subroutine) {
    out << " (" << block->context.subroutine->name << ')';
  }
  out << nxl;
  // block variable initialization
  if (!block->initialized_vars.empty()) {
    out << "// var inits" << nxl;
    writeVarInits(prefix, out, block->initialized_vars, _dependencies, _ff_usage);
    out << "// --" << nxl;
  }
  for (const auto &a : block->instructions) {
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
            reportError(assign->getSourceInterval(), (int)assign->getStart()->getLine(), "cannot assign a variable bound to an expression");
          }
        }
        // write
        writeAssignement(prefix, out, a, assign->access(), assign->IDENTIFIER(), assign->expression_0(), &block->context, FF_Q, _dependencies, _ff_usage);
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
              writeAssignement(prefix, ostr, a, alw->access(), alw->IDENTIFIER(), alw->expression_0(), &block->context, FF_Q, _dependencies, _ff_usage);
              // modify assignement to insert temporary var
              std::size_t pos = ostr.str().find('=');
              std::string lvalue = ostr.str().substr(0, pos - 1);
              std::string rvalue = ostr.str().substr(pos + 1);
              std::string tmpvar = "_delayed_" + std::to_string(alw->getStart()->getLine()) + "_" + std::to_string(alw->getStart()->getCharPositionInLine());
              out << lvalue << " = " << FF_D << tmpvar << ';' << nxl;
              out << FF_D << tmpvar << " = " << rvalue; // rvalue includes the line end ";\n"
            } else {
              writeAssignement(prefix, out, a, alw->access(), alw->IDENTIFIER(), alw->expression_0(), &block->context, FF_Q, _dependencies, _ff_usage);
            }
          }
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
        if (display->displayParams() != nullptr) {
          for (auto p : display->displayParams()->IDENTIFIER()) {
            out << "," << rewriteIdentifier(prefix, p->getText(), &block->context, display->getStart()->getLine(), FF_Q, true, _dependencies, _ff_usage);
          }
        }
        out << ");" << nxl;
      }
    } {
      auto async = dynamic_cast<siliceParser::AsyncExecContext *>(a.instr);
      if (async) {
        // find algorithm
        auto A = m_InstancedAlgorithms.find(async->IDENTIFIER()->getText());
        if (A == m_InstancedAlgorithms.end()) {
          // check if this is an erronous call to a subroutine
          auto S = m_Subroutines.find(async->IDENTIFIER()->getText());
          if (S == m_Subroutines.end()) {
            reportError(async->getSourceInterval(), (int)async->getStart()->getLine(),
              "cannot find algorithm '%s' on asynchronous call",
              async->IDENTIFIER()->getText().c_str());
          } else {
            reportError(async->getSourceInterval(), (int)async->getStart()->getLine(),
              "cannot perform an asynchronous call on subroutine '%s'",
              async->IDENTIFIER()->getText().c_str());
          }
        } else {
          writeAlgorithmCall(a.instr, prefix, out, A->second, async->paramList(), &block->context, _dependencies, _ff_usage);
        }
      }
    } {
      auto sync = dynamic_cast<siliceParser::SyncExecContext *>(a.instr);
      if (sync) {
        // find algorithm
        auto A = m_InstancedAlgorithms.find(sync->joinExec()->IDENTIFIER()->getText());
        if (A == m_InstancedAlgorithms.end()) {
          // call to a subroutine?
          auto S = m_Subroutines.find(sync->joinExec()->IDENTIFIER()->getText());
          if (S == m_Subroutines.end()) {
            reportError(sync->getSourceInterval(), (int)sync->getStart()->getLine(),
              "cannot find algorithm '%s' on synchronous call",
              sync->joinExec()->IDENTIFIER()->getText().c_str());
          } else {
            writeSubroutineCall(a.instr, prefix, out, S->second, &block->context, sync->paramList(), _dependencies, _ff_usage);
          }
        } else {
          writeAlgorithmCall(a.instr, prefix, out, A->second, sync->paramList(), &block->context, _dependencies, _ff_usage);
        }
      }
    } {
      auto join = dynamic_cast<siliceParser::JoinExecContext *>(a.instr);
      if (join) {
        // find algorithm
        auto A = m_InstancedAlgorithms.find(join->IDENTIFIER()->getText());
        if (A == m_InstancedAlgorithms.end()) {
          // return of subroutine?
          auto S = m_Subroutines.find(join->IDENTIFIER()->getText());
          if (S == m_Subroutines.end()) {
            reportError(join->getSourceInterval(), (int)join->getStart()->getLine(),
              "cannot find algorithm '%s' to join with",
              join->IDENTIFIER()->getText().c_str(), (int)join->getStart()->getLine());
          } else {
            writeSubroutineReadback(a.instr, prefix, out, S->second, &block->context, join->assignList(), _ff_usage);
          }
        } else {
          writeAlgorithmReadback(a.instr, prefix, out, A->second, join->assignList(), &block->context, _ff_usage);
        }
      }
    }
    // update dependencies
    updateAndCheckDependencies(_dependencies, a.instr, &block->context);
  }
}

// -------------------------------------------------

void Algorithm::writeStatelessBlockGraph(std::string prefix, std::ostream& out, const t_combinational_block* block, const t_combinational_block* stop_at, std::queue<size_t>& _q, t_vio_dependencies& _dependencies, t_vio_ff_usage &_ff_usage) const
{
  // recursive call?
  if (stop_at != nullptr) {
    sl_assert(!(block->is_state && block->is_sub_state));
    // if called on a state, index state and stop there
    if (block->is_state) {
      // yes: index the state directly
      out << FF_D << prefix << ALG_IDX " = " << toFSMState(fastForward(block)->state_id) << ";" << nxl;
      pushState(block, _q);
      // return
      return;
    }
    // if called on a sub-state, no nothing but stop here
    if (block->is_sub_state) {
      return;
    }
  }
  // follow the chain
  const t_combinational_block *current = block;
  while (true) {
    // write current block
    writeBlock(prefix, out, current, _dependencies, _ff_usage);
    // goto next in chain
    if (current->next()) {
      current = current->next()->next;
    } else if (current->if_then_else()) {
      out << "if (" << rewriteExpression(prefix, current->if_then_else()->test.instr, current->if_then_else()->test.__id, &current->context, FF_Q, true, _dependencies, _ff_usage) << ") begin" << nxl;
      vector<t_vio_ff_usage> usage_branches;
      // recurse if
      t_vio_dependencies depds_if = _dependencies; 
      usage_branches.push_back(t_vio_ff_usage());
      writeStatelessBlockGraph(prefix, out, current->if_then_else()->if_next, current->if_then_else()->after, _q, depds_if, usage_branches.back());
      out << "end else begin" << nxl;
      // recurse else
      t_vio_dependencies depds_else = _dependencies;
      usage_branches.push_back(t_vio_ff_usage());
      writeStatelessBlockGraph(prefix, out, current->if_then_else()->else_next, current->if_then_else()->after, _q, depds_else, usage_branches.back());
      out << "end" << nxl;
      // merge dependencies
      mergeDependenciesInto(depds_if, _dependencies);
      mergeDependenciesInto(depds_else, _dependencies);
      // combine ff usage
      combineFFUsageInto(_ff_usage, usage_branches, _ff_usage);
      // follow after?
      if (current->if_then_else()->after->is_state) {
        return; // no: already indexed by recursive calls
      } else {
        current = current->if_then_else()->after; // yes!
      }
    } else if (current->switch_case()) {
      out << "  case (" << rewriteExpression(prefix, current->switch_case()->test.instr, current->switch_case()->test.__id, &current->context, FF_Q, true, _dependencies, _ff_usage) << ")" << nxl;
      // recurse block
      t_vio_dependencies depds_before_case = _dependencies;
      vector<t_vio_ff_usage> usage_branches;
      bool has_default = false;
      for (auto cb : current->switch_case()->case_blocks) {
        out << "  " << cb.first << ": begin" << nxl;
        has_default = has_default | (cb.first == "default");
        // recurse case
        t_vio_dependencies depds_case = depds_before_case;
        usage_branches.push_back(t_vio_ff_usage());
        writeStatelessBlockGraph(prefix, out, cb.second, current->switch_case()->after, _q, depds_case, usage_branches.back());
        // merge sets of written vars
        mergeDependenciesInto(depds_case, _dependencies);
        out << "  end" << nxl;
      }
      // end of case
      out << "endcase" << nxl;
      // merge ff usage
      if (!has_default) {
        usage_branches.push_back(t_vio_ff_usage()); // push an empty set
        // NOTE: the case could be complete, currently not checked ; safe but missing an opportunity
      }
      combineFFUsageInto(_ff_usage, usage_branches, _ff_usage);
      // follow after?
      if (current->switch_case()->after->is_state) {
        return; // no: already indexed by recursive calls
      } else {
        current = current->switch_case()->after; // yes!
      }
    } else if (current->while_loop()) {
      // while
      out << "if (" << rewriteExpression(prefix, current->while_loop()->test.instr, current->while_loop()->test.__id, &current->context, FF_Q, true, _dependencies, _ff_usage) << ") begin" << nxl;
      writeStatelessBlockGraph(prefix, out, current->while_loop()->iteration, current->while_loop()->after, _q, _dependencies, _ff_usage);
      out << "end else begin" << nxl;
      out << FF_D << prefix << ALG_IDX " = " << toFSMState(fastForward(current->while_loop()->after)->state_id) << ";" << nxl;
      pushState(current->while_loop()->after, _q);
      out << "end" << nxl;
      return;
    } else if (current->return_from()) {
      // return to caller (goes to termination of algorithm is not set)
      sl_assert(current->context.subroutine != nullptr);
      auto RS = m_SubroutinesCallerReturnStates.find(current->context.subroutine->name);
      if (RS != m_SubroutinesCallerReturnStates.end()) {
        if (RS->second.size() > 1) {
          out << "case (" << FF_D << prefix << ALG_CALLER << ") " << nxl;
          for (auto caller_return : RS->second) {
            out << stateWidth() << "'d" << caller_return.first << ": begin" << nxl;
            out << "  " << FF_D << prefix << ALG_IDX " = " << stateWidth() << "'d" << toFSMState(fastForward(caller_return.second)->state_id) << ';' << nxl;
            // if returning to a subroutine, restore caller id
            if (caller_return.second->context.subroutine != nullptr) {
              sl_assert(caller_return.second->context.subroutine->contains_calls);
              out << "  " << FF_D << prefix << ALG_CALLER << " = " << FF_Q << prefix << caller_return.second->context.subroutine->name << '_' << ALG_CALLER << ';' << nxl;
            }
            out << "end" << nxl;
          }
          out << "default:" << FF_D << prefix << ALG_IDX " = " << stateWidth() << "'d" << terminationState() << ';' << nxl;
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
      sl_assert(current->parent_state_id > -1);
      out << FF_D << prefix << ALG_CALLER << " = " << current->parent_state_id << ";" << nxl;
      pushState(current->goto_and_return_to()->return_to, _q);
      return;
    } else if (current->wait()) {
      // wait for algorithm
      auto A = m_InstancedAlgorithms.find(current->wait()->algo_instance_name);
      if (A == m_InstancedAlgorithms.end()) {
        reportError(nullptr,(int)current->wait()->line,
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
      return;
    } else if (current->pipeline_next()) {
      // write pipeline
      current = writeStatelessPipeline(prefix,out,current, _q,_dependencies, _ff_usage);
    } else { // necessary as m_AlwaysPre reaches this
      if (!hasNoFSM()) { 
        // no action, goto end
        out << FF_D << prefix << ALG_IDX " = " << toFSMState(terminationState()) << ";" << nxl;
      }
      return;
    }
    // check whether next is a state
    if (current->is_state) {
      // yes: index and stop
      out << FF_D << prefix << ALG_IDX " = " << toFSMState(fastForward(current)->state_id) << ";" << nxl;
      pushState(current, _q);
      return;
    }
    // check whether next is a sub-state
    if (current->is_sub_state) {
      return;
    }
    // reached stop?
    if (current == stop_at) {
      return;
    }
    // keep going
  }
}

// -------------------------------------------------

const Algorithm::t_combinational_block *Algorithm::writeStatelessPipeline(
  std::string prefix, std::ostream& out, 
  const t_combinational_block* block_before, 
  std::queue<size_t>& _q, t_vio_dependencies& _dependencies, t_vio_ff_usage &_ff_usage) const
{
  // follow the chain
  out << "// pipeline" << nxl;
  const t_combinational_block *current = block_before->pipeline_next()->next;
  const t_combinational_block *after   = block_before->pipeline_next()->after;
  const t_pipeline_nfo        *pip     = current->context.pipeline->pipeline;
  sl_assert(pip != nullptr);
  while (true) {
    sl_assert(pip == current->context.pipeline->pipeline);
    // write stage
    int stage = current->context.pipeline->stage_id;
    out << "// stage " << stage << nxl;
    // write code
    t_vio_dependencies deps;
    if (current != after) { // this is the more complex case of multiple blocks in stage
      writeStatelessBlockGraph(prefix, out, current, after, _q, deps, _ff_usage); // NOTE: q will not be changed since this is a combinational block
      current = after;
    } else {
      writeBlock(prefix, out, current, deps, _ff_usage);
    }
    // trickle vars
    for (auto tv : pip->trickling_vios) {
      if (stage >= tv.second[0] && stage < tv.second[1]) {
        out << FF_D << prefix << tricklingVIOName(tv.first, pip, stage + 1)
          << " = ";
        updateFFUsage(e_D, false, _ff_usage.ff_usage[tricklingVIOName(tv.first, pip, stage + 1)]);
        std::string tricklingsrc = tricklingVIOName(tv.first, pip, stage);
        if (stage == tv.second[0]) {
          out << rewriteIdentifier(prefix, tv.first, &current->context, -1, FF_D, true, _dependencies, _ff_usage);
        } else {
          out << FF_Q << prefix << tricklingsrc;
          updateFFUsage(e_Q, true, _ff_usage.ff_usage[tricklingsrc]);
        }
        out << ';' << nxl;
      }
    }
    // advance
    if (current->pipeline_next()) {
      after   = current->pipeline_next()->after;
      current = current->pipeline_next()->next;
    } else {
      sl_assert(current->next() != nullptr);
      return current->next()->next;
    }
  }
  return current;
}

// -------------------------------------------------

void Algorithm::writeVarInits(std::string prefix, std::ostream& out, const std::unordered_map<std::string, int >& varnames, t_vio_dependencies& _dependencies, t_vio_ff_usage &_ff_usage) const
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
    string ff = (v.usage == e_FlipFlop) ? FF_D : FF_TMP;
    if (v.table_size == 0) {
      out << ff << prefix << v.name << " = " << v.init_values[0] << ';' << nxl;
    } else {
      ForIndex(i, v.table_size) {
        out << ff << prefix << v.name << "[" << i << ']' << " = " << v.init_values[i] << ';' << nxl;
      }
    }
    // insert write in dependencies
    _dependencies.dependencies.insert(std::make_pair(v.name, 0));
  }
}

// -------------------------------------------------

void Algorithm::prepareModuleMemoryTemplateReplacements(const t_mem_nfo& bram, std::unordered_map<std::string, std::string>& _replacements) const
{
  string memid;
  std::vector<t_mem_member> members;
  switch (bram.mem_type) {
  case BRAM:     members = c_BRAMmembers; memid = "bram";  break;
  case BROM:     members = c_BROMmembers; memid = "brom"; break;
  case DUALBRAM: members = c_DualPortBRAMmembers; memid = "dualport_bram"; break;
  default: reportError(nullptr, -1, "internal error, memory type"); break;
  }
  _replacements["MODULE"] = m_Name;
  _replacements["NAME"] = bram.name;
  for (const auto& m : members) {
    string nameup = m.name;
    std::transform(nameup.begin(), nameup.end(), nameup.begin(),
      [](unsigned char c) { return std::toupper(c); }
    );
    if (m.is_addr) {
      _replacements[nameup + "_WIDTH"] = std::to_string(justHigherPow2(bram.table_size) - 1);
    } else {
      // search config
      string width = ""; // bit-width - 1 (written as top of verilog range)
      auto C = CONFIG.keyValues().find(memid + "_" + m.name + "_width");
      if (C == CONFIG.keyValues().end()) {
        width = std::to_string(bram.type_nfo.width - 1);
      } else if (C->second == "1") {
        width = "0";
      } else if (C->second == "data") {
        width = std::to_string(bram.type_nfo.width - 1);
      }
      _replacements[nameup + "_WIDTH"] = width;
      // search config
      string sgnd = "";
      auto T = CONFIG.keyValues().find(memid + "_" + m.name + "_type");
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
  _replacements["DATA_WIDTH"] = std::to_string(bram.type_nfo.width - 1);
  _replacements["DATA_SIZE"] = std::to_string(bram.table_size - 1);
  ostringstream initial;
  if (!bram.do_not_initialize) {
    initial << "initial begin" << endl;
    ForIndex(v, bram.init_values.size()) {
      initial << " buffer[" << v << "] = " << bram.init_values[v] << ';' << endl;
    }
    initial << "end" << endl;
  }
  _replacements["INITIAL"] = initial.str();
  _replacements["CLOCK"]   = ALG_CLOCK;
}

// -------------------------------------------------

void Algorithm::writeModuleMemoryBRAM(std::ostream& out, const t_mem_nfo& bram) const
{
  // prepare replacement vars
  std::unordered_map<std::string, std::string> replacements;
  prepareModuleMemoryTemplateReplacements(bram, replacements);
  // load template
  VerilogTemplate tmplt;
  tmplt.load(CONFIG.keyValues()["templates_path"] + "/" + CONFIG.keyValues()["bram_template"],
    replacements);
  // write to output
  out << tmplt.code();
  out << endl;
}

// -------------------------------------------------

void Algorithm::writeModuleMemoryBROM(std::ostream& out, const t_mem_nfo& bram) const
{
  // prepare replacement vars
  std::unordered_map<std::string, std::string> replacements;
  prepareModuleMemoryTemplateReplacements(bram, replacements);
  // load template
  VerilogTemplate tmplt;
  tmplt.load(CONFIG.keyValues()["templates_path"] + "/" + CONFIG.keyValues()["brom_template"],
    replacements);
  // write to output
  out << tmplt.code();
  out << endl;
}

// -------------------------------------------------

void Algorithm::writeModuleMemoryDualPortBRAM(std::ostream& out, const t_mem_nfo& bram) const
{
  // prepare replacement vars
  std::unordered_map<std::string, std::string> replacements;
  prepareModuleMemoryTemplateReplacements(bram, replacements);
  // load template
  VerilogTemplate tmplt;
  tmplt.load(CONFIG.keyValues()["templates_path"] + "/" + CONFIG.keyValues()["dualport_bram_template"],
    replacements);
  // write to output
  out << tmplt.code();
  out << endl;
}

// -------------------------------------------------

void Algorithm::writeModuleMemory(std::ostream& out, const t_mem_nfo& mem) const
{
  switch (mem.mem_type)     {
  case BRAM:     writeModuleMemoryBRAM(out, mem); break;
  case BROM:     writeModuleMemoryBROM(out, mem); break;
  case DUALBRAM: writeModuleMemoryDualPortBRAM(out, mem); break;
  default: throw Fatal("internal error (unkown memory type)"); break;
  }
}

// -------------------------------------------------

void Algorithm::writeAsModule(std::ostream &out)
{
  // first pass, discarded but used to fine tune detection of temporary vars
  {
    t_vio_ff_usage ff_usage;
    std::ofstream null;
    writeAsModule(null, ff_usage);

    // update usage based on first pass
    for (const auto &v : ff_usage.ff_usage) {
      if (!(v.second & e_Q)) {
        if (m_VarNames.count(v.first)) {
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
          // if there is no FSM, the algorithm is combinational and outputs do not need to be latched
          if (m_OutputNames.count(v.first)) {
            if (m_Outputs.at(m_OutputNames.at(v.first)).usage == e_FlipFlop) {
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

  {
    t_vio_ff_usage ff_usage;
    writeAsModule(out, ff_usage);
  }
}

// -------------------------------------------------

const Algorithm::t_binding_nfo &Algorithm::findBindingTo(std::string var, const std::vector<t_binding_nfo> &bndgs) const
{
  for (const auto &b : bndgs) {
    if (b.left == var) {
      return b;
    }
  }
  throw Fatal("internal error [findBindingTo]");
  static t_binding_nfo foo;
  return foo;
}

// -------------------------------------------------

template <typename T> 
void copyToVarNfo(Algorithm::t_var_nfo &_nfo, const T &src)
{
  _nfo.name = src.name;
  _nfo.type_nfo = src.type_nfo;
  _nfo.init_values = src.init_values;
  _nfo.table_size = src.table_size;
  _nfo.do_not_initialize = src.do_not_initialize;
  _nfo.access = src.access;
  _nfo.usage = src.usage;
  _nfo.attribs = src.attribs;
}

// -------------------------------------------------

bool Algorithm::getVIONfo(std::string vio, t_var_nfo& _nfo) const
{
  {
    auto I = m_InputNames.find(vio);
    if (I != m_InputNames.end()) {
      copyToVarNfo(_nfo, m_Inputs[I->second]);
      return true;
    }
  } {
    auto Io = m_InOutNames.find(vio);
    if (Io != m_InOutNames.end()) {
      copyToVarNfo(_nfo, m_InOuts[Io->second]);
      return true;
    }
  } {
    auto O = m_OutputNames.find(vio);
    if (O != m_OutputNames.end()) {
      copyToVarNfo(_nfo, m_Outputs[O->second]);
      return true;
    }
  } {
    auto V = m_VarNames.find(vio);
    if (V != m_VarNames.end()) {
      copyToVarNfo(_nfo, m_Vars[V->second]);
      return true;
    }
  }
  return false;
}

// -------------------------------------------------

void Algorithm::writeAsModule(ostream& out, t_vio_ff_usage& _ff_usage) const
{
  out << endl;

  // write memory modules
  for (const auto& mem : m_Memories) {
    writeModuleMemory(out, mem);
  }

  // module header
  out << "module M_" << m_Name << ' ';
  if (!m_Parameterized.empty()) {
    out << "#(" << endl;
    // parameters for parameterized variables
    ForIndex(i,m_Parameterized.size()) {
      string str = m_Parameterized[i];
      std::transform(str.begin(), str.end(), str.begin(),
        [](unsigned char c) -> unsigned char { return std::toupper(c); });
      out << "parameter " << str << "_WIDTH=1";
      // out << "parameter " << str << "_SIGNED=\"\"";
      if (i + 1 < m_Parameterized.size()) {
        out << ',';
      }
      out << endl;
    }
    out << ") ";
  }
  // list ports names
  out << '(' << endl;
  for (const auto &v : m_Inputs) {
    out << string(ALG_INPUT) << '_' << v.name << ',' << endl;
  }
  for (const auto &v : m_Outputs) {
    out << string(ALG_OUTPUT) << '_' << v.name << ',' << endl;
  }
  for (const auto &v : m_InOuts) {
    out << string(ALG_INOUT) << '_' << v.name << ',' << endl;
  }
  if (!hasNoFSM()) {
    out << ALG_INPUT << "_" << ALG_RUN << ',' << endl;
    out << ALG_OUTPUT << "_" << ALG_DONE << ',' << endl;
  }
  if (!requiresNoReset()) {
    out << ALG_RESET "," << endl;
  }
  out << "out_" << ALG_CLOCK "," << endl;
  out << ALG_CLOCK << endl;
  out << ");" << endl;
  // declare ports
  for (const auto& v : m_Inputs) {
    sl_assert(v.table_size == 0);
    writeVerilogDeclaration(out, "input", v, string(ALG_INPUT) + "_" + v.name );
    // out << "input " << typeString(v) << " " << varBitRange(v) << " " << ALG_INPUT << '_' << v.name << ';' << endl;
  }
  for (const auto& v : m_Outputs) {
    sl_assert(v.table_size == 0);
    writeVerilogDeclaration(out, "output", v, string(ALG_OUTPUT) + "_" + v.name);
    // out << "output " << typeString(v) << " " << varBitRange(v) << " " << ALG_OUTPUT << '_' << v.name << ';' << endl;
  }
  for (const auto& v : m_InOuts) {
    sl_assert(v.table_size == 0);
    writeVerilogDeclaration(out, "inout", v, string(ALG_INOUT) + "_" + v.name);
    // out << "inout " << typeString(v) << " " << varBitRange(v) << " " << ALG_INOUT << '_' << v.name << ';' << endl;
  }
  if (!hasNoFSM()) {
    out << "input " << ALG_INPUT << "_" << ALG_RUN << ';' << endl;
    out << "output " << ALG_OUTPUT << "_" << ALG_DONE << ';' << endl;
  }
  if (!requiresNoReset()) {
    out << "input " ALG_RESET ";" << endl;
  }
  out << "output out_" ALG_CLOCK << ";" << endl;
  out << "input " ALG_CLOCK << ";" << endl;

  // assign algorithm clock to output clock
  {
    t_vio_dependencies _1, _2;
    out << "assign out_" ALG_CLOCK << " = " 
      << rewriteIdentifier("_", m_Clock, nullptr, -1, FF_Q, true, _1, _ff_usage) 
      << ';' << nxl;
  }

  // module instantiations (1/2)
  // -> required wires to hold outputs
  for (auto& nfo : m_InstancedModules) {
    std::string  wire_prefix = WIRE + nfo.second.instance_prefix;
    for (auto b : nfo.second.bindings) {
      if (b.dir == e_Right) {
        auto O = nfo.second.mod->output(b.left);
        if (O.first == 0 && O.second == 0) {
          out << "wire " << wire_prefix + "_" + b.left;
        } else {
          out << "wire[" << O.first << ':' << O.second << "] " << wire_prefix + "_" + b.left;
        }
        out << ';' << endl;
      }
    }
  }

  // algorithm instantiations (1/2) 
  // -> required wires to hold outputs
  for (const auto& iaiordr : m_InstancedAlgorithmsInDeclOrder) {
    const auto &nfo = m_InstancedAlgorithms.at(iaiordr);
    // output wires
    for (const auto& os : nfo.algo->m_Outputs) {
      sl_assert(os.table_size == 0);
      // is the output parameterized?
      if (os.type_nfo.base_type == Parameterized) {
        // find binding
        const auto &b = findBindingTo(os.name, nfo.bindings);
        std::string bound = bindingRightIdentifier(b);
        t_var_nfo bnfo;
        if (!getVIONfo(bound, bnfo)) {
          reportError(nullptr, nfo.instance_line, "cannot determine binding source type for binding between '%s' and '%s', instance '%s'",
            os.name.c_str(), bound.c_str(), nfo.instance_name.c_str());
        }
        writeVerilogDeclaration(out, "wire", bnfo, std::string(WIRE) + nfo.instance_prefix + '_' + os.name);
        // out << "wire " << typeString(bnfo) << " " << varBitRange(bnfo) << " " << WIRE << nfo.instance_prefix << '_' << os.name << ';' << endl;
      } else {
        writeVerilogDeclaration(out, "wire", os, std::string(WIRE) + nfo.instance_prefix + '_' + os.name);
        // out << "wire " << typeString(os) << " " << varBitRange(os) << " " << WIRE << nfo.instance_prefix << '_' << os.name << ';' << endl;
      }
    }
    if (!nfo.algo->hasNoFSM()) {
      // algorithm done
      out << "wire " << WIRE << nfo.instance_prefix << '_' << ALG_DONE << ';' << endl;
    }
  }
  // Memory instantiations (1/2)
  for (const auto& mem : m_Memories) {
    // output wires
    for (const auto& ouv : mem.out_vars) {
      const auto& os = m_Vars[m_VarNames.at(ouv)];
      writeVerilogDeclaration(out, "wire", os, std::string(WIRE) + "_mem_" + os.name);
      // out << "wire " << typeString(os) << " " << varBitRange(os) << " " << WIRE << "_mem_" << os.name << ';' << endl;
    }
  }

  // const declarations
  writeConstDeclarations("_", out);

  // temporary vars declarations
  writeTempDeclarations("_", out);

  // wire declaration (vars bound to inouts)
  writeWireDeclarations("_", out);

  // flip-flops declarations
  writeFlipFlopDeclarations("_", out);

  // output assignments
  for (const auto& v : m_Outputs) {
    sl_assert(v.table_size == 0);
    if (v.usage == e_FlipFlop) {
      out << "assign " << ALG_OUTPUT << "_" << v.name << " = ";
      out << (v.combinational ? FF_D : FF_Q);
      out << "_" << v.name << ';' << endl;
      if (v.combinational) {
        updateFFUsage(e_D, true, _ff_usage.ff_usage[v.name]);
      } else {
        updateFFUsage(e_Q, true, _ff_usage.ff_usage[v.name]);
      }
    } else if (v.usage == e_Temporary) {
        out << "assign " << ALG_OUTPUT << "_" << v.name << " = " << FF_TMP << "_" << v.name << ';' << endl;
    } else if (v.usage == e_Bound) {
        out << "assign " << ALG_OUTPUT << "_" << v.name << " = " << m_VIOBoundToModAlgOutputs.at(v.name) << ';' << endl;
    } else {
      throw Fatal("internal error");
    }
  }

  // algorithm done
  if (!hasNoFSM()) {
    out << "assign " << ALG_OUTPUT << "_" << ALG_DONE << " = (" << FF_Q << "_" << ALG_IDX << " == " << toFSMState(terminationState()) << ");" << endl;
  }

  // flip-flops update
  writeFlipFlops("_", out);

  out << endl;

  // module instantiations (2/2)
  // -> module instances
  for (auto& nfo : m_InstancedModules) {
    std::string  wire_prefix = WIRE + nfo.second.instance_prefix;
    // write module instantiation
    out << endl;
    out << nfo.second.module_name << ' ' << nfo.second.instance_prefix << " (" << endl;
    bool first = true;
    for (auto b : nfo.second.bindings) {
      if (!first) out << ',' << endl;
      first = false;
      if (b.dir == e_Left || b.dir == e_LeftQ) {
        // input
        t_vio_dependencies _;
        out << '.' << b.left << '('
          << rewriteIdentifier("_", bindingRightIdentifier(b), nullptr, nfo.second.instance_line, 
            b.dir == e_LeftQ ? FF_Q : FF_D, true, _, _ff_usage, e_DQ /*force module inputs to be latched*/
          )
          << ")";
      } else if (b.dir == e_Right) {
        // output (wire)
        out << '.' << b.left << '(' << wire_prefix + "_" + b.left << ")";
      } else {
        // inout (host algorithm inout or wire)
        sl_assert(b.dir == e_BiDir);
        std::string bindpoint = nfo.second.instance_prefix + "_" + b.left;
        const auto& vio = m_ModAlgInOutsBoundToVIO.find(bindpoint);
        if (vio != m_ModAlgInOutsBoundToVIO.end()) {
          if (isInOut(bindingRightIdentifier(b))) {
            out << '.' << b.left << '(' << ALG_INOUT << "_" << bindingRightIdentifier(b) << ")";
          } else {
            out << '.' << b.left << '(' << WIRE << "_" << bindingRightIdentifier(b) << ")";
          }
        } else {
          reportError(nullptr,b.line,"cannot find module inout binding '%s'", b.left.c_str());
        }
      }
    }
    out << endl << ");" << endl;
  }

  // algorithm instantiations (2/2) 
  for (const auto& iaiordr : m_InstancedAlgorithmsInDeclOrder) {
    const auto &nfo = m_InstancedAlgorithms.at(iaiordr);
    // algorithm module
    out << "M_" << nfo.algo_name << ' ';
    // parameters
    if (!nfo.algo->m_Parameterized.empty()) {
      out << "#(" << endl;
      // parameters for parameterized variables
      ForIndex(i, nfo.algo->m_Parameterized.size()) {
        string var = nfo.algo->m_Parameterized[i];
        // find binding
        const auto& b     = findBindingTo(var, nfo.bindings);
        std::string bound = bindingRightIdentifier(b);
        t_var_nfo bnfo;
        if (!getVIONfo(bound, bnfo)) {
          reportError(nullptr, nfo.instance_line, "cannot determine binding source type for binding between generic '%s' and '%s', instance '%s'", 
            var.c_str(),bound.c_str(), nfo.instance_name.c_str());
        }
        // for now, signed cannot be taken into account
        if (bnfo.type_nfo.base_type == Int) {
          reportError(nullptr, nfo.instance_line, "signed binding sources are not supported, generic '%s' bound to (signed) '%s', instance '%s')",
            var.c_str(), bound.c_str(), nfo.instance_name.c_str());
        }
        // write
        std::transform(var.begin(), var.end(), var.begin(),
          [](unsigned char c) -> unsigned char { return std::toupper(c); });
        out << '.' << var << "_WIDTH";
        out << '(' << varBitWidth(bnfo) << ')';
        //out << ',' << endl;
        //out << '.' << var << "_SIGNED";
        //out << "(\"" << typeString(bnfo) << "\")";
        if (i + 1 < nfo.algo->m_Parameterized.size()) {
          out << ',';
        }
        out << endl;
      }
      out << ") ";
    }
    // instance name
    out << nfo.instance_name << ' ';
    // ports
    out << '(' << endl;
    // inputs
    for (const auto &is : nfo.algo->m_Inputs) {
      out << '.' << ALG_INPUT << '_' << is.name << '(';
      if (nfo.boundinputs.count(is.name) > 0) {
        // input is bound, directly map bound VIO
        t_vio_dependencies _;
        out << rewriteIdentifier("_", nfo.boundinputs.at(is.name).first, nullptr, nfo.instance_line, 
          nfo.boundinputs.at(is.name).second == e_Q ? FF_Q : FF_D, true, _, _ff_usage, 
          nfo.boundinputs.at(is.name).second == e_Q ? e_Q : (is.nolatch ? e_D : e_DQ /*force inputs to be latched by default*/) );
      } else {
        // input is not bound and assigned in logic, a specifc flip-flop is created for this
        out << FF_D << nfo.instance_prefix << "_" << is.name;
        // add to usage
        updateFFUsage(is.nolatch ? e_D : e_DQ /*force inputs to be latched by default*/, true, _ff_usage.ff_usage[nfo.instance_prefix + "_" + is.name]);
      }
      out << ')' << ',' << endl;
    }
    // outputs (wire)
    for (const auto& os : nfo.algo->m_Outputs) {
      out << '.'
        << ALG_OUTPUT << '_' << os.name
        << '(' << WIRE << nfo.instance_prefix << '_' << os.name << ')';
      out << ',' << endl;
    }
    // inouts (host algorithm inout or wire)
    for (const auto& os : nfo.algo->m_InOuts) {
      std::string bindpoint = nfo.instance_prefix + "_" + os.name;
      const auto& vio = m_ModAlgInOutsBoundToVIO.find(bindpoint);
      if (vio != m_ModAlgInOutsBoundToVIO.end()) {
        if (isInOut(vio->second)) {
          out << '.' << ALG_INOUT << '_' << os.name << '(' << ALG_INOUT << "_" << vio->second << ")";
        } else {
          out << '.' << ALG_INOUT << '_' << os.name << '(' << WIRE << "_" << vio->second << ")";
        }
        out << ',' << endl;
      } else {
        reportError(nullptr, nfo.instance_line, "cannot find algorithm inout binding '%s'", os.name.c_str());
      }
    }
    if (!nfo.algo->hasNoFSM()) {
      // done
      out << '.' << ALG_OUTPUT << '_' << ALG_DONE
        << '(' << WIRE << nfo.instance_prefix << '_' << ALG_DONE << ')';
      out << ',' << endl;
      // run
      out << '.' << ALG_INPUT << '_' << ALG_RUN
        << '(' << nfo.instance_prefix << '_' << ALG_RUN << ')';
      out << ',' << endl;
    }
    // reset
    if (!nfo.algo->requiresNoReset()) {
      t_vio_dependencies _;
      out << '.' << ALG_RESET << '(' << rewriteIdentifier("_", nfo.instance_reset, nullptr, nfo.instance_line, FF_Q, true, _, _ff_usage) << ")," << endl;
    }
    // clock
    {
      t_vio_dependencies _;
      out << '.' << ALG_CLOCK << '(' << rewriteIdentifier("_", nfo.instance_clock, nullptr, nfo.instance_line, FF_Q, true, _, _ff_usage) << ")" << endl;
    }
    // end of instantiation      
    out << ");" << endl;
  }
  out << endl;

  // Memory instantiations (2/2)
  for (const auto& mem : m_Memories) {
    // module
    out << "M_" << m_Name << "_mem_" << mem.name << " __mem__" << mem.name << '(' << endl;
    // clocks
    if (mem.clocks.empty()) {
      if (mem.mem_type == DUALBRAM) {
        t_vio_dependencies _1,_2;
        out << '.' << ALG_CLOCK << "0(" << rewriteIdentifier("_", m_Clock, nullptr, mem.line, FF_Q, true, _1, _ff_usage) << ")," << endl;
        out << '.' << ALG_CLOCK << "1(" << rewriteIdentifier("_", m_Clock, nullptr, mem.line, FF_Q, true, _2, _ff_usage) << ")," << endl;
      } else {
        t_vio_dependencies _;
        out << '.' << ALG_CLOCK << '(' << rewriteIdentifier("_", m_Clock, nullptr, mem.line, FF_Q, true, _, _ff_usage) << ")," << endl;
      }
    } else {
      sl_assert(mem.mem_type == DUALBRAM && mem.clocks.size() == 2);
      std::string clk0 = mem.clocks[0];
      std::string clk1 = mem.clocks[1];
      t_vio_dependencies _1, _2;
      out << '.' << ALG_CLOCK << "0(" << rewriteIdentifier("_", clk0, nullptr, mem.line, FF_D, true, _1, _ff_usage) << ")," << endl;
      out << '.' << ALG_CLOCK << "1(" << rewriteIdentifier("_", clk1, nullptr, mem.line, FF_D, true, _2, _ff_usage) << ")," << endl;
    }
    // inputs
    for (const auto& inv : mem.in_vars) {
      t_vio_dependencies _;
      out << '.' << ALG_INPUT << '_' << inv << '(' << rewriteIdentifier("_", inv, nullptr, mem.line, mem.delayed ? FF_Q : FF_D, true, _, _ff_usage,
      mem.delayed ? e_Q : (mem.no_input_latch ? e_D : e_DQ /*latch inputs*/ )
      ) << ")," << endl;
    }
    // output wires
    int num = (int)mem.out_vars.size();
    for (const auto& ouv : mem.out_vars) {
      out << '.' << ALG_OUTPUT << '_' << ouv << '(' << WIRE << "_mem_" << ouv << ')';
      if (num-- > 1) {
        out << ',' << endl;
      } else {
        out << endl;
      }
    }
    // end of instantiation      
    out << ");" << endl;
  }
  out << endl;

  // wire assignments
  t_vio_dependencies always_dependencies;
  writeWireAssignements("_", out, always_dependencies, _ff_usage);
  // combinational
  out << "always @* begin" << endl;
  writeCombinationalAlwaysPre("_", out, always_dependencies, _ff_usage);
  if (!hasNoFSM()) {
    // write all states
    writeCombinationalStates("_", out, always_dependencies, _ff_usage);
  }
  out << "end" << endl;

  out << "endmodule" << endl;
  out << endl;
}

// -------------------------------------------------
