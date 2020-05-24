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

using namespace std;
using namespace antlr4;

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
      bool is_input = (im.second.mod->inputs()  .find(b.left) != im.second.mod->inputs().end());
      bool is_output = (im.second.mod->outputs().find(b.left) != im.second.mod->outputs().end());
      bool is_inout = (im.second.mod->inouts()  .find(b.left) != im.second.mod->inouts().end());
      if (!is_input && !is_output && !is_inout) {
        reportError(nullptr, b.line, "wrong binding point (neither input nor output), instanced module '%s', binding '%s'",
          im.first.c_str(), b.left.c_str());
      }
      if (b.dir == e_Left && !is_input) { // input
        reportError(nullptr, b.line, "wrong binding direction, instanced module '%s', binding output '%s'",
          im.first.c_str(), b.left.c_str());
      }
      if (b.dir == e_Right && !is_output) { // output
        reportError(nullptr, b.line, "wrong binding direction, instanced module '%s', binding input '%s'",
          im.first.c_str(), b.left.c_str());
      }
      // check right side
      if (!isInputOrOutput(b.right) && !isInOut(b.right)
        && m_VarNames.count(b.right) == 0 
        && b.right != m_Clock && b.right != ALG_CLOCK
        && b.right != m_Reset && b.right != ALG_RESET) {
        reportError(nullptr, b.line, "wrong binding point, instanced module '%s', binding to '%s'",
          im.first.c_str(), b.right.c_str());
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::checkAlgorithmsBindings() const
{
  for (auto& ia : m_InstancedAlgorithms) {
    for (const auto& b : ia.second.bindings) {
      // check left side
      bool is_input  = ia.second.algo->isInput (b.left);
      bool is_output = ia.second.algo->isOutput(b.left);
      bool is_inout  = ia.second.algo->isInOut (b.left);
      if (!is_input && !is_output && !is_inout) {
        reportError(nullptr, b.line, "wrong binding point (neither input nor output), instanced algorithm '%s', binding '%s'",
          ia.first.c_str(), b.left.c_str());
      }
      if (b.dir == e_Left && !is_input) { // input
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
      if (!isInputOrOutput(b.right) && !isInOut(b.right)
        && m_VarNames.count(b.right) == 0
        && b.right != m_Clock && b.right != ALG_CLOCK
        && b.right != m_Reset && b.right != ALG_RESET) {
        reportError(nullptr, b.line, "wrong binding point, instanced algorithm '%s', binding to '%s'",
          ia.first.c_str(), b.right.c_str());
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
        bnfo.line = _mod.instance_line;
        bnfo.left = io.first;
        bnfo.right = io.first;
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
          bnfo.right = io.first;
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
        bnfo.right = io;
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
        bnfo.right = io.first;
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
          bnfo.right = io.first;
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
        bnfo.right = io.first;
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
          bnfo.right = io.first;
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
        bnfo.right = io.name;
        bnfo.dir = e_Left;
        _alg.bindings.push_back(bnfo);
      } else // check if algorithm has a var with same name
        if (m_VarNames.find(io.name) != m_VarNames.end()) {
          // yes: autobind
          t_binding_nfo bnfo;
          bnfo.line = _alg.instance_line;
          bnfo.left = io.name;
          bnfo.right = io.name;
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
        bnfo.right = io;
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
        bnfo.right = io.name;
        bnfo.dir = e_Right;
        _alg.bindings.push_back(bnfo);
      } else // check if algorithm has a var with same name
        if (m_VarNames.find(io.name) != m_VarNames.end()) {
          // yes: autobind
          t_binding_nfo bnfo;
          bnfo.line = _alg.instance_line;
          bnfo.left = io.name;
          bnfo.right = io.name;
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
        bnfo.right = io.name;
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
          bnfo.right = io.name;
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
  for (auto& b : _alg.bindings) {
    if (b.dir == e_Auto) {
      // input?
      if (_alg.algo->isInput(b.left)) {
        b.dir = e_Left;
      }
      // output?
      else if (_alg.algo->isOutput(b.left)) {
        b.dir = e_Right;
      }
      // inout?
      else if (_alg.algo->isInOut(b.left)) {
        b.dir = e_BiDir;
      } else {
        reportError(nullptr, b.line, "cannot determine binding direction for '%s <:> %s', binding to algorithm instance '%s'",
          b.left.c_str(), b.right.c_str(), _alg.instance_name.c_str());
      }
    }
  }
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

template<class T_Block>
Algorithm::t_combinational_block *Algorithm::addBlock(std::string name, const t_combinational_block_context* bctx, int line)
{
  auto B = m_State2Block.find(name);
  if (B != m_State2Block.end()) {
    reportError(nullptr, line, "state name '%s' already defined", name.c_str());
  }
  size_t next_id = m_Blocks.size();
  m_Blocks.emplace_back(new T_Block());
  m_Blocks.back()->block_name = name;
  m_Blocks.back()->id = next_id;
  m_Blocks.back()->end_action = nullptr;
  if (bctx != nullptr) {
    m_Blocks.back()->context.subroutine   = bctx->subroutine;
    m_Blocks.back()->context.pipeline     = bctx->pipeline;
    m_Blocks.back()->context.vio_rewrites = bctx->vio_rewrites;
  }
  m_Id2Block[next_id] = m_Blocks.back();
  m_State2Block[name] = m_Blocks.back();
  return m_Blocks.back();
}

// -------------------------------------------------

void Algorithm::splitType(std::string type, e_Type& _type, int& _width)
{
  std::regex  rx_type("([[:alpha:]]+)([[:digit:]]+)");
  std::smatch sm_type;
  bool ok = std::regex_search(type, sm_type, rx_type);
  sl_assert(ok);
  // type
  if (sm_type[1] == "int")  _type = Int;
  else if (sm_type[1] == "uint") _type = UInt;
  else sl_assert(false);
  // width
  _width = atoi(sm_type[2].str().c_str());
}

// -------------------------------------------------

void Algorithm::splitConstant(std::string cst, int& _width, char& _base, std::string& _value, bool& _negative) const
{
  std::regex  rx_type("(-?)([[:digit:]]+)([bdh])([[:digit:]a-fA-Fxz]+)");
  std::smatch sm_type;
  bool ok = std::regex_search(cst, sm_type, rx_type);
  sl_assert(ok);
  _width = atoi(sm_type[2].str().c_str());
  _base = sm_type[3].str()[0];
  _value = sm_type[4].str();
  _negative = !sm_type[1].str().empty();
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

std::string Algorithm::gatherValue(siliceParser::ValueContext* ival)
{
  if (ival->CONSTANT() != nullptr) {
    return rewriteConstant(ival->CONSTANT()->getText());
  } else if (ival->NUMBER() != nullptr) {
    std::string sign = ival->minus != nullptr ? "-" : "";
    return sign + ival->NUMBER()->getText();
  } else {
    sl_assert(false);
  }
  return "";
}

// -------------------------------------------------

void Algorithm::addVar(t_var_nfo& _var, t_subroutine_nfo* sub,int line)
{
  if (sub != nullptr) {
    std::string base_name = _var.name;
    _var.name = subroutineVIOName(base_name, sub);
    sub->vios.insert(std::make_pair(base_name, _var.name));
    sub->vars.push_back(base_name);
    sub->allowed_reads .insert(_var.name);
    sub->allowed_writes.insert(_var.name);
  }
  // verify the variable does not shadow an input or output
  if (isInput(_var.name)) {
    reportError(nullptr, line, "variable '%s' is shadowing input of same name", _var.name.c_str());
  } else if (isOutput(_var.name)) {
    reportError(nullptr, line, "variable '%s' is shadowing output of same name", _var.name.c_str());
  }
  // ok!
  m_Vars.emplace_back(_var);
  m_VarNames.insert(std::make_pair(_var.name, (int)m_Vars.size() - 1));
  if (sub != nullptr) {
    sub->varnames.insert(std::make_pair(_var.name, (int)m_Vars.size() - 1));
  }
}

// -------------------------------------------------

void Algorithm::gatherVarNfo(siliceParser::DeclarationVarContext* decl, t_var_nfo& _nfo)
{
  _nfo.name = decl->IDENTIFIER()->getText();
  _nfo.table_size = 0;
  splitType(decl->TYPE()->getText(), _nfo.base_type, _nfo.width);
  _nfo.init_values.push_back("0");
  _nfo.init_values[0] = gatherValue(decl->value());
  if (decl->ATTRIBS() != nullptr) {
    _nfo.attribs = decl->ATTRIBS()->getText();
  }
}

// -------------------------------------------------

void Algorithm::gatherDeclarationVar(siliceParser::DeclarationVarContext* decl, t_subroutine_nfo* sub)
{
  t_var_nfo var;
  gatherVarNfo(decl,var);
  addVar(var, sub, (int)decl->getStart()->getLine());
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
    return; // no init list
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

void Algorithm::gatherDeclarationTable(siliceParser::DeclarationTableContext* decl, t_subroutine_nfo* sub)
{
  t_var_nfo var;
  if (sub == nullptr) {
    var.name = decl->IDENTIFIER()->getText();
  } else {
    var.name = subroutineVIOName(decl->IDENTIFIER()->getText(), sub);
    sub->vios.insert(std::make_pair(decl->IDENTIFIER()->getText(), var.name));
    sub->vars.push_back(decl->IDENTIFIER()->getText());
  }
  splitType(decl->TYPE()->getText(), var.base_type, var.width);
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
  m_Vars.emplace_back(var);
  m_VarNames.insert(std::make_pair(var.name, (int)m_Vars.size() - 1));
  if (sub != nullptr) {
    sub->varnames.insert(std::make_pair(var.name, (int)m_Vars.size() - 1));
  }
}

// -------------------------------------------------

static int justHigherPow2(int n)
{
  int p2 = 0;
  while (n > 0) {
    p2++;
    n = n >> 1;
  }
  return p2;
}

// -------------------------------------------------

typedef struct {
  bool        is_input;
  std::string name;
  int         width; // -1 if same as bram declared type
} t_mem_member;

const std::vector<t_mem_member> c_BRAMmembers = {
  {true,"wenable",1},
  {false,"rdata",-1},
  {true,"wdata",-1}
  // addr is always added
};

const std::vector<t_mem_member> c_BROMmembers = {
  {false,"rdata",-1}
  // addr is always added
};

// -------------------------------------------------

void Algorithm::gatherDeclarationMemory(siliceParser::DeclarationMemoryContext* decl, const t_subroutine_nfo* sub)
{
  if (sub != nullptr) {
    reportError(decl->getSourceInterval(), (int)decl->getStart()->getLine(), "subroutine '%s': a memory cannot be instanced within a subroutine", sub->name.c_str());
  }
  // gather memory nfo
  t_mem_nfo mem;
  mem.name = decl->name->getText();
  if (decl->BRAM() != nullptr) {
    mem.mem_type = BRAM;
  } else if (decl->BROM() != nullptr) {
    mem.mem_type = BROM;
  } else {
    reportError(decl->getSourceInterval(), (int)decl->getStart()->getLine(), "internal error, memory declaration");
  }
  splitType(decl->TYPE()->getText(), mem.base_type, mem.width);
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
  mem.line = (int)decl->getStart()->getLine();
  // create bound variables for access
  std::vector<t_mem_member> members;
  switch (mem.mem_type)     {
  case BRAM: members = c_BRAMmembers; break;
  case BROM: members = c_BROMmembers; break;
  default: reportError(decl->getSourceInterval(), (int)decl->getStart()->getLine(), "internal error, memory declaration"); break;
  }
  // -> create var for address
  {
    t_var_nfo v;
    v.name = mem.name + "_addr";
    v.base_type = UInt;
    v.width = justHigherPow2(mem.table_size);
    v.table_size = 0;
    v.init_values.push_back("0");
    v.usage = e_Bound;
    addVar(v, nullptr, (int)decl->getStart()->getLine());
    mem.in_vars.push_back(v.name);
    m_VIOBoundToModAlgOutputs[v.name] = WIRE "_mem_" + v.name;
  }
  // other members
  for (const auto& m : members) {
    t_var_nfo v;
    v.name = mem.name + "_" + m.name;
    if (m.width == -1) {
      v.base_type = mem.base_type;
      v.width = mem.width;
    } else {
      v.base_type = UInt;
      v.width = mem.width;
    }
    v.table_size = 0;
    v.init_values.push_back("0");
    v.usage = e_Bound;
    addVar(v, nullptr, (int)decl->getStart()->getLine());
    if (m.is_input) {
      mem.in_vars.push_back(v.name);
    } else {
      mem.out_vars.push_back(v.name);
    }
    m_VIOBoundToModAlgOutputs[v.name] = WIRE "_mem_" + v.name;
  }
  // add memory
  m_Memories.emplace_back(mem);
  m_MemoryNames.insert(make_pair(mem.name, (int)m_Memories.size()-1));
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
        // checkl if this is a group binding
        if (bindings->modalgBinding()->BDEFINE() != nullptr) {
          auto G = m_VIOGroups.find(bindings->modalgBinding()->right->getText());
          if (G != m_VIOGroups.end()) {
            // unfold all bindings, select direction automatically
            for (auto v : G->second->varList()->var()) {
              string member = v->declarationVar()->IDENTIFIER()->getText();
              t_binding_nfo nfo;
              nfo.left  = bindings->modalgBinding()->left->getText() + "_" + member;
              nfo.right = bindings->modalgBinding()->right->getText() + "_" + member;
              nfo.line  = (int)bindings->modalgBinding()->getStart()->getLine();
              nfo.dir   = e_Auto;
              _vec_bindings.push_back(nfo);
            }
            // skip to next
            bindings = bindings->modalgBindingList();
            continue;
          }
        }
        t_binding_nfo nfo;
        nfo.left = bindings->modalgBinding()->left->getText();
        nfo.right = bindings->modalgBinding()->right->getText();
        nfo.line = (int)bindings->modalgBinding()->getStart()->getLine();
        if (bindings->modalgBinding()->LDEFINE() != nullptr) {
          nfo.dir = e_Left;
        } else if (bindings->modalgBinding()->RDEFINE() != nullptr) {
          nfo.dir = e_Right;
        } else {
          sl_assert(bindings->modalgBinding()->BDEFINE() != nullptr);
          nfo.dir = e_BiDir;
        }
        _vec_bindings.push_back(nfo);
      }
    }
    bindings = bindings->modalgBindingList();
  }
}

// -------------------------------------------------

void Algorithm::gatherDeclarationGroup(siliceParser::DeclarationGrpModAlgContext* grp, t_subroutine_nfo* sub)
{
  auto G = m_KnownGroups.find(grp->modalg->getText());
  if (G != m_KnownGroups.end()) {
    m_VIOGroups.insert(make_pair(grp->name->getText(), G->second));
    for (auto v : G->second->varList()->var()) {
      t_var_nfo vnfo;
      gatherVarNfo(v->declarationVar(), vnfo);
      vnfo.name = grp->name->getText() + "_" + vnfo.name;
      addVar(vnfo, sub, (int)grp->getStart()->getLine());
    }
  } else {
    reportError(grp->getSourceInterval(), (int)grp->getStart()->getLine(), "unkown group '%s'", grp->modalg->getText().c_str());
  }
}

// -------------------------------------------------

void Algorithm::gatherDeclarationAlgo(siliceParser::DeclarationGrpModAlgContext* alg, const t_subroutine_nfo* sub)
{
  if (sub != nullptr) {
    reportError(alg->getSourceInterval(), (int)alg->name->getLine(), "subroutine '%s': algorithms cannot be instanced within subroutines", sub->name.c_str());
  }
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
}

// -------------------------------------------------

void Algorithm::gatherDeclarationModule(siliceParser::DeclarationGrpModAlgContext* mod, const t_subroutine_nfo* sub)
{
  if (sub != nullptr) {
    reportError(mod->name,(int)mod->name->getLine(),"subroutine '%s': modules cannot be instanced within subroutines", sub->name.c_str());
  }
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
  size_t line, std::string ff, const t_vio_dependencies& dependencies) const
{
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
      if (usage == e_FlipFlop) {
        if (ff == FF_Q) {
          if (dependencies.dependencies.count(var) > 0) {
            return FF_D + prefix + var;
          }
        }
        return ff + prefix + var;
      } else if (usage == e_Bound) {
        return m_VIOBoundToModAlgOutputs.at(var);
      } else {
        // should be e_Assigned ; currently replaced by a flip-flop but could be avoided
        reportError(nullptr, -1, "assigned outputs: not yet implemented");
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
        } else {
          // flip-flop
          if (ff == FF_Q) {
            if (dependencies.dependencies.count(var) > 0) {
              return FF_D + prefix + var;
            }
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

std::string Algorithm::rewriteExpression(std::string prefix, antlr4::tree::ParseTree *expr, int __id, const t_combinational_block_context *bctx, const t_vio_dependencies& dependencies) const
{
  std::string result;
  if (expr->children.empty()) {
    auto term = dynamic_cast<antlr4::tree::TerminalNode*>(expr);
    if (term) {
      if (term->getSymbol()->getType() == siliceParser::IDENTIFIER) {
        return rewriteIdentifier(prefix, expr->getText(), bctx, term->getSymbol()->getLine(), FF_Q, dependencies);
      } else if (term->getSymbol()->getType() == siliceParser::CONSTANT) {
        return rewriteConstant(expr->getText());
      } else if (term->getSymbol()->getType() == siliceParser::REPEATID) {
        if (__id == -1) {
          reportError(term->getSymbol(), (int)term->getSymbol()->getLine(), "__id used outside of repeat block");
        }
        return std::to_string(__id);
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
      writeAccess(prefix, ostr, false, access, __id, bctx, dependencies);
      result = result + ostr.str();
    } else {
      // recurse
      for (auto c : expr->children) {
        result = result + rewriteExpression(prefix, c, __id, bctx, dependencies);
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

Algorithm::t_combinational_block *Algorithm::updateBlock(siliceParser::InstructionListContext* ilist, t_combinational_block *_current, t_gather_context *_context)
{
  if (ilist->state() != nullptr) {
    // start a new block
    std::string name = "++";
    if (ilist->state()->state_name != nullptr) {
      name = ilist->state()->state_name->getText();
    }
    bool no_skip = false;
    if (name == "++") {
      name = generateBlockName();
      no_skip = true;
    }
    t_combinational_block *block = addBlock(name, &_current->context, (int)ilist->state()->getStart()->getLine());
    block->is_state = true; // block explicitely required to be a state
    block->no_skip = no_skip;
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
  t_combinational_block *block = addBlock(generateBlockName(), &_current->context);
  // return block
  return block;
}

// -------------------------------------------------

Algorithm::t_combinational_block *Algorithm::gatherWhile(siliceParser::WhileLoopContext* loop, t_combinational_block *_current, t_gather_context *_context)
{
  // while header block
  t_combinational_block *while_header = addBlock("__while" + generateBlockName(), &_current->context);
  _current->next(while_header);
  // iteration block
  t_combinational_block *iter = addBlock(generateBlockName(), &_current->context);
  // block for after the while
  t_combinational_block *after = addBlock(generateBlockName(), &_current->context);
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

void Algorithm::gatherDeclaration(siliceParser::DeclarationContext *decl, t_subroutine_nfo *sub)
{
  auto declvar   = dynamic_cast<siliceParser::DeclarationVarContext*>(decl->declarationVar());
  auto decltbl   = dynamic_cast<siliceParser::DeclarationTableContext*>(decl->declarationTable());
  auto grpmodalg = dynamic_cast<siliceParser::DeclarationGrpModAlgContext*>(decl->declarationGrpModAlg());
  auto declmem   = dynamic_cast<siliceParser::DeclarationMemoryContext*>(decl->declarationMemory());
  if (declvar)        { gatherDeclarationVar(declvar, sub); } 
  else if (decltbl)   { gatherDeclarationTable(decltbl, sub); } 
  else if (declmem)   { gatherDeclarationMemory(declmem, sub); }
  else if (grpmodalg) {
    std::string name = grpmodalg->modalg->getText();
    if (m_KnownGroups.find(name) != m_KnownGroups.end()) {
      gatherDeclarationGroup(grpmodalg, sub);
    } else if (m_KnownModules.find(name) != m_KnownModules.end()) {
      gatherDeclarationModule(grpmodalg, sub);
    } else {
      gatherDeclarationAlgo(grpmodalg, sub);
    }
  }
}

//-------------------------------------------------

int Algorithm::gatherDeclarationList(siliceParser::DeclarationListContext* decllist, t_subroutine_nfo* sub)
{
  if (decllist == nullptr) {
    return 0;
  }
  int num = 0;
  siliceParser::DeclarationListContext *cur_decllist = decllist;
  while (cur_decllist->declaration() != nullptr) {
    siliceParser::DeclarationContext* decl = cur_decllist->declaration();
    gatherDeclaration(decl, sub);
    cur_decllist = cur_decllist->declarationList();
    ++num;
  }
  return num;
}

// -------------------------------------------------

Algorithm::t_combinational_block *Algorithm::gatherSubroutine(siliceParser::SubroutineContext* sub, t_combinational_block *_current, t_gather_context *_context)
{
  sl_assert(_current->context.subroutine == nullptr);

  t_subroutine_nfo *nfo = new t_subroutine_nfo;
  // subroutine name
  nfo->name = sub->IDENTIFIER()->getText();
  // check for duplicates
  if (m_Subroutines.count(nfo->name) > 0) {
    reportError(sub->IDENTIFIER()->getSymbol(), (int)sub->getStart()->getLine(),"subroutine '%s': a subroutine of the same name is already declared", nfo->name.c_str());
  }
  if (m_InstancedAlgorithms.count(nfo->name) > 0) {
    reportError(sub->IDENTIFIER()->getSymbol(), (int)sub->getStart()->getLine(),"subroutine '%s': an instanced algorithm of the same name is already declared", nfo->name.c_str());
  }
  // subroutine local declarations
  int numdecl = gatherDeclarationList(sub->declarationList(), nfo);
  // subroutine block
  t_combinational_block *subb = addBlock(SUB_ENTRY_BLOCK + nfo->name, nullptr, (int)sub->getStart()->getLine());
  if (numdecl > 0) {
    subb->no_skip = true; // do not skip if local vars must be initialized
  }
  // cross ref between block and subroutine
  subb->context.subroutine = nfo;
  nfo->top_block           = subb;
  // gather inputs/outputs and access constraints
  sl_assert(sub->subroutineParamList() != nullptr);
  // constraint?
  for (auto P : sub->subroutineParamList()->subroutineParam()) {
    if (P->READ() != nullptr) {
      nfo->allowed_reads.insert(P->IDENTIFIER()->getText());
      // if memory, add all out members
      auto B = m_MemoryNames.find(P->IDENTIFIER()->getText());
      if (B != m_MemoryNames.end()) {
        for (const auto& ouv : m_Memories[B->second].out_vars) {
          nfo->allowed_reads.insert(ouv);
        }
      }
      // if group, add all members
      auto G = m_VIOGroups.find(P->IDENTIFIER()->getText());
      if (G != m_VIOGroups.end()) {
        for (auto v : G->second->varList()->var()) {
          string mbr = v->declarationVar()->IDENTIFIER()->getText();
          nfo->allowed_reads.insert(mbr);
        }
      }
    } else if (P->WRITE() != nullptr) {
      nfo->allowed_writes.insert(P->IDENTIFIER()->getText());
      // if memory, add all in members
      auto B = m_MemoryNames.find(P->IDENTIFIER()->getText());
      if (B != m_MemoryNames.end()) {
        for (const auto& inv : m_Memories[B->second].in_vars) {
          nfo->allowed_writes.insert(inv);
        }
      }
      // if group, add all members
      auto G = m_VIOGroups.find(P->IDENTIFIER()->getText());
      if (G != m_VIOGroups.end()) {
        for (auto v : G->second->varList()->var()) {
          string mbr = v->declarationVar()->IDENTIFIER()->getText();
          nfo->allowed_writes.insert(mbr);
        }
      }
    } else if (P->READWRITE() != nullptr) {
      nfo->allowed_reads.insert(P->IDENTIFIER()->getText());
      nfo->allowed_writes.insert(P->IDENTIFIER()->getText());
      // if memory, add all in/out members
      auto B = m_MemoryNames.find(P->IDENTIFIER()->getText());
      if (B != m_MemoryNames.end()) {
        for (const auto& ouv : m_Memories[B->second].out_vars) {
          nfo->allowed_reads.insert(ouv);
        }
        for (const auto& inv : m_Memories[B->second].in_vars) {
          nfo->allowed_writes.insert(inv);
          nfo->allowed_reads .insert(inv);
        }
      }
      // if group, add all members
      auto G = m_VIOGroups.find(P->IDENTIFIER()->getText());
      if (G != m_VIOGroups.end()) {
        for (auto v : G->second->varList()->var()) {
          string mbr = P->IDENTIFIER()->getText() + "_" + v->declarationVar()->IDENTIFIER()->getText();
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
          tbl_size = atoi(P->input()->NUMBER()->getText().c_str());
        }
        nfo->inputs.push_back(ioname);
      } else {
        in_or_out = "o";
        ioname = P->output()->IDENTIFIER()->getText();
        strtype = P->output()->TYPE()->getText();
        if (P->output()->NUMBER() != nullptr) {
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
      splitType(strtype, var.base_type, var.width);
      var.init_values.resize(max(var.table_size, 1), "0");
      m_Vars.emplace_back(var);
      m_VarNames.insert(std::make_pair(var.name, (int)m_Vars.size() - 1));
      nfo->vios.insert(std::make_pair(ioname, var.name));
      // add to allowed read/write list
      if (P->input() != nullptr) {
        nfo->allowed_reads .insert(var.name);
      } else {
        nfo->allowed_writes.insert(var.name);
      }
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
  t_combinational_block *after = addBlock(generateBlockName(), &_current->context);
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
    nfo->stages.push_back(snfo);
    snfo->pipeline = nfo;
    snfo->stage_id = stage;
    // blocks
    t_combinational_block_context ctx = { _current->context.subroutine, snfo };
    t_combinational_block *stage_start = addBlock("__stage_" + generateBlockName(), &ctx, (int)b->getStart()->getLine());
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
      std::cerr << "vio " << r.first << " read at stage " << s << std::endl;
    }
  }
  // report on written variables
  for (auto w : written_at) {
    for (auto s : w.second) {
      std::cerr << "vio " << w.first << " written at stage " << s;
      std::cerr << std::endl;
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
    std::cerr << tv << " trickling from " << last_write << " to " << last_read << std::endl;
    // info from source var
    auto tws = determineVIOTypeWidthAndTableSize(&_current->context, tv, (int)pip->getStart()->getLine());
    // generate one flip-flop per stage
    ForRange(s, last_write+1, last_read) {
      // -> add variable
      t_var_nfo var;
      var.name = tricklingVIOName(tv,nfo,s);
      var.base_type = get<0>(tws);
      var.width = get<1>(tws);
      var.table_size = get<2>(tws);
      var.init_values.resize(var.table_size > 0 ? var.table_size : 1, "0");
      var.access = e_InternalFlipFlop;
      m_Vars.emplace_back(var);
      m_VarNames.insert(std::make_pair(var.name, (int)m_Vars.size() - 1));
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
  t_combinational_block* after = addBlock(generateBlockName(), &_current->context);
  // return block after jump
  return after;
}

// -------------------------------------------------

Algorithm::t_combinational_block *Algorithm::gatherCall(siliceParser::CallContext* call, t_combinational_block *_current, t_gather_context *_context)
{
  // start a new block just after the call
  t_combinational_block* after = addBlock(generateBlockName(), &_current->context);
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
  t_combinational_block* block = addBlock(generateBlockName(), &_current->context);
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
    t_combinational_block* after = addBlock(generateBlockName(), &_current->context);
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
    t_combinational_block* waiting_block = addBlock(generateBlockName(), &_current->context);
    waiting_block->is_state = true; // state for waiting
    // enter wait after current
    _current->next(waiting_block);
    // block for after the wait
    t_combinational_block* next_block = addBlock(generateBlockName(), &_current->context);
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
    if (cur->is_state) {
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

Algorithm::t_combinational_block* Algorithm::gatherCircuitryInst(siliceParser::CircuitryInstContext* ci, t_combinational_block* _current, t_gather_context* _context)
{
  // find circuitry in known circuitries
  std::string name = ci->IDENTIFIER()->getText();
  auto C = m_KnownCircuitries.find(name);
  if (C == m_KnownCircuitries.end()) {
    reportError(ci->IDENTIFIER()->getSymbol(), (int)ci->getStart()->getLine(), "circuitry not yet declared");
  }
  // instantiate in a new block
  t_combinational_block* cblock = addBlock(generateBlockName() + "_" + name, &_current->context);
  _current->next(cblock);
  // produce io rewrite rules for the block
  /// TODO: deal with memories
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
    cblock->context.vio_rewrites.insert(make_pair(ins[i], ins_idents[i]));
  }
  ForIndex(o, outs.size()) {
    cblock->context.vio_rewrites.insert(make_pair(outs[o], outs_idents[o]));
  }
  // gather code
  t_combinational_block* cblock_after = gather(C->second->instructionList(), cblock, _context);
  // create a new block to continue with same context as _current
  t_combinational_block* after = addBlock(generateBlockName(), &_current->context);
  cblock_after->next(after);
  return after;
}

// -------------------------------------------------

Algorithm::t_combinational_block *Algorithm::gatherIfElse(siliceParser::IfThenElseContext* ifelse, t_combinational_block *_current, t_gather_context *_context)
{
  t_combinational_block *if_block = addBlock(generateBlockName(), &_current->context);
  t_combinational_block *else_block = addBlock(generateBlockName(), &_current->context);
  // parse the blocks
  t_combinational_block *if_block_after = gather(ifelse->if_block, if_block, _context);
  t_combinational_block *else_block_after = gather(ifelse->else_block, else_block, _context);
  // create a block for after the if-then-else
  t_combinational_block *after = addBlock(generateBlockName(), &_current->context);
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
  t_combinational_block *if_block = addBlock(generateBlockName(), &_current->context);
  t_combinational_block *else_block = addBlock(generateBlockName(), &_current->context);
  // parse the blocks
  t_combinational_block *if_block_after = gather(ifthen->if_block, if_block, _context);
  // create a block for after the if-then-else
  t_combinational_block *after = addBlock(generateBlockName(), &_current->context);
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
  t_combinational_block* after = addBlock(generateBlockName(), &_current->context);
  // create a block per case statement
  std::vector<std::pair<std::string, t_combinational_block*> > case_blocks;
  for (auto cb : switchCase->caseBlock()) {
    t_combinational_block* case_block = addBlock(generateBlockName() + "_case", &_current->context);
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
        std::pair<e_Type, int> type_width = determineAccessTypeAndWidth(nullptr, alw->access(), alw->IDENTIFIER());
        var.table_size = 0;
        var.base_type = type_width.first;
        var.width = type_width.second;
        var.init_values.push_back("0");
        m_Vars.emplace_back(var);
        m_VarNames.insert(std::make_pair(var.name, (int)m_Vars.size() - 1));
      }
    }
    alws = alws->alwaysAssignedList();
  }
}

// -------------------------------------------------

void Algorithm::checkPermissions(antlr4::tree::ParseTree *node, t_combinational_block *_current)
{
  // in subroutine
  if (_current->context.subroutine == nullptr) {
    return; // no, return, no checks required
  }
  // yes: go ahead with checks
  std::unordered_set<std::string> read, written;
  determineVIOAccess(node, m_VarNames,    &_current->context, read, written);
  determineVIOAccess(node, m_OutputNames, &_current->context, read, written);
  determineVIOAccess(node, m_InputNames,  &_current->context, read, written);
  // now verify all permissions are granted
  for (auto R : read) {
    if (_current->context.subroutine->allowed_reads.count(R) == 0) {
      reportError(nullptr, -1, "variable '%s' is read by subroutine '%s' without explicit permission", R.c_str(), _current->context.subroutine->name.c_str());
    }
  }
  for (auto W : written) {
    if (_current->context.subroutine->allowed_writes.count(W) == 0) {
      reportError(nullptr, -1, "variable '%s' is written by subroutine '%s' without explicit permission", W.c_str(), _current->context.subroutine->name.c_str());
    }
  }
}

// -------------------------------------------------

void Algorithm::gatherInputNfo(siliceParser::InputContext* input,t_inout_nfo& _io)
{
  _io.name = input->IDENTIFIER()->getText();
  _io.table_size = 0;
  splitType(input->TYPE()->getText(), _io.base_type, _io.width);
  if (input->NUMBER() != nullptr) {
    _io.table_size = atoi(input->NUMBER()->getText().c_str());
  }
  _io.init_values.resize(max(_io.table_size, 1), "0");
}

// -------------------------------------------------

void Algorithm::gatherOutputNfo(siliceParser::OutputContext* output, t_output_nfo& _io)
{
  _io.name = output->IDENTIFIER()->getText();
  _io.table_size = 0;
  splitType(output->TYPE()->getText(), _io.base_type, _io.width);
  if (output->NUMBER() != nullptr) {
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
  splitType(inout->TYPE()->getText(), _io.base_type, _io.width);
  if (inout->NUMBER() != nullptr) {
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
      inp.base_type    = V->second.base_type;
      inp.width        = V->second.width;
      m_Inputs.emplace_back(inp);
      m_InputNames.insert(make_pair(inp.name, (int)m_Inputs.size() - 1));
    } else if (io->is_inout != nullptr) {
      t_inout_nfo inp;
      inp.name = grpre + "_" + V->second.name;
      inp.table_size  = V->second.table_size;
      inp.init_values = V->second.init_values;
      inp.base_type   = V->second.base_type;
      inp.width       = V->second.width;
      m_InOuts.emplace_back(inp);
      m_InOutNames.insert(make_pair(inp.name, (int)m_InOuts.size() - 1));
    } else if (io->is_output != nullptr) {
      t_output_nfo oup;
      oup.name = grpre + "_" + V->second.name;
      oup.table_size    = V->second.table_size;
      oup.init_values   = V->second.init_values;
      oup.combinational = (io->combinational != nullptr);
      oup.base_type     = V->second.base_type;
      oup.width         = V->second.width;
      m_Outputs.emplace_back(oup);
      m_OutputNames.insert(make_pair(oup.name, (int)m_Outputs.size() - 1));
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
    auto input   = dynamic_cast<siliceParser::InputContext*>(io->input());
    auto output  = dynamic_cast<siliceParser::OutputContext*>(io->output());
    auto inout   = dynamic_cast<siliceParser::InoutContext*>(io->inout());
    auto iogroup = dynamic_cast<siliceParser::IoGroupContext*>(io->ioGroup());
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

Algorithm::t_combinational_block *Algorithm::gather(antlr4::tree::ParseTree *tree, t_combinational_block *_current, t_gather_context *_context)
{
  if (tree == nullptr) {
    return _current;
  }

  auto algbody  = dynamic_cast<siliceParser::DeclAndInstrListContext*>(tree);
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

  bool recurse = true;

  checkPermissions(tree, _current);

  if (algbody) {
    // gather declarations
    for (auto d : algbody->declaration()) {
      gatherDeclaration(dynamic_cast<siliceParser::DeclarationContext *>(d), nullptr);
    }
    for (auto s : algbody->subroutine()) {
      gatherSubroutine(dynamic_cast<siliceParser::SubroutineContext *>(s), _current, _context);
    }
    // gather always assigned
    gatherAlwaysAssigned(algbody->alwaysPre, &m_AlwaysPre);
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
    _current = gather(algbody->instructionList(),_current, _context);
    recurse  = false;
  } else if (ifelse) { 
    _current = gatherIfElse(ifelse, _current, _context);                               recurse = false;
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
  } else if (ilist)    { _current = updateBlock(ilist, _current, _context); }

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
  m_MaxState = 0;
  std::unordered_set< t_combinational_block* > visited;
  std::queue< t_combinational_block* > q;
  q.push(m_Blocks.front()); // start from main
  while (!q.empty()) {
    auto cur = q.front();
    q.pop();
    // test
    if (cur->is_state) {
      sl_assert(cur->state_id == -1);
      cur->state_id = m_MaxState++;
    }
    // recurse
    std::vector< t_combinational_block* > children;
    cur->getChildren(children);
    for (auto c : children) {
      if (visited.find(c) == visited.end()) {
        visited.insert(c);
        q.push(c);
      }
    }
  }
  // additional internal state
  m_MaxState++;
  // report
  std::cerr << "algorithm " << m_Name << " num states: " << m_MaxState << std::endl;
}

// -------------------------------------------------

int Algorithm::maxState() const
{
  return m_MaxState;
}

// -------------------------------------------------

int Algorithm::entryState() const
{
  // TODO: but not so simple, can lead to trouble with var inits, 
  // for instance if the entry state becomes the first in a lopp
  // fastForward(m_Blocks.front())->state_id 

  return 0;
}

// -------------------------------------------------

int Algorithm::terminationState() const
{
  return m_MaxState - 1;
}

// -------------------------------------------------

int Algorithm::stateWidth() const
{
  int max_s = maxState();
  int w = 0;
  while (max_s > (1 << w)) {
    w++;
  }
  return w;
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

void Algorithm::updateDependencies(t_vio_dependencies& _depds, antlr4::tree::ParseTree* instr, const t_combinational_block_context *bctx) const
{
  if (instr == nullptr) {
    return;
  }
  // record which vars were written before
  std::unordered_set<std::string> written_before;
  for (const auto& d : _depds.dependencies) {
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
    std::cerr << "---- after line " << dynamic_cast<antlr4::ParserRuleContext*>(instr)->getStart()->getLine() << std::endl;
    for (auto w : _depds.dependencies) {
      std::cerr << "var " << w.first << " depds on ";
      for (auto r : w.second) {
        std::cerr << r << ' ';
      }
      std::cerr << std::endl;
    }
    std::cerr << std::endl;
  }

  // check if everything is legit
  // for each written variable
  for (const auto& w : written) {
    // check if the variable was written before
    if (written_before.count(w) > 0) {
      // yes: does it depend on itself?
      const auto& d = _depds.dependencies.at(w);
      if (d.count(w) > 0) {
        // yes: this would produce a combinational cycle, error!
        reportError(
          dynamic_cast<antlr4::ParserRuleContext *>(instr)->getSourceInterval(),
          (int)(dynamic_cast<antlr4::ParserRuleContext *>(instr)->getStart()->getLine()),
          "variable assignement leads to a combinational cycle (variable: %s)\n\nConsider inserting a sequential split with '++:'",
          w.c_str());
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

void Algorithm::verifyMemberMemory(const t_mem_nfo& mem, std::string member, int line) const
{
  bool found = false;
  for (const auto& v : mem.in_vars) {
    if (v == mem.name + "_" + member) {
      found = true; break;
    }
  }
  for (const auto& v : mem.out_vars) {
    if (v == mem.name + "_" + member) {
      found = true; break;
    }
  }
  if (!found) {
    reportError(nullptr,line,"memory '%s' has no member '%s'", mem.name.c_str(), member.c_str());
  }
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
    group->IDENTIFIER()->getText().c_str(), member, line);
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
    auto B = m_MemoryNames.find(base);
    if (B != m_MemoryNames.end()) {
      const auto& mem = m_Memories[B->second];
      verifyMemberMemory(mem, member, (int)access->getStart()->getLine());
      // return the variable name
      return base + "_" + member;
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
  }
  return "";
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
        std::string var;
        if (assign->access() != nullptr) {
          var = determineAccessedVar(assign->access(),bctx);
        } else {
          var = assign->IDENTIFIER()->getText();
        }
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
          }
        }
        recurse = false;
      }
    } {
      auto alw = dynamic_cast<siliceParser::AlwaysAssignedContext*>(node);
      if (alw) {
        std::string var;
        if (alw->access() != nullptr) {
          var = determineAccessedVar(alw->access(),bctx);
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
          // internal vars init
          for (const auto& vn : S->second->vars) {
            std::string varname = S->second->vios.at(vn);
            const auto& v = m_Vars.at(m_VarNames.at(varname));
            if (v.usage != e_FlipFlop) continue;
            if (vios.find(varname) != vios.end()) {
              _written.insert(varname);
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

void Algorithm::determineVariablesAccess(t_combinational_block *block)
{
  // determine variable access
  std::unordered_set<std::string> already_read;
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
    std::unordered_set<std::string> read;
    std::unordered_set<std::string> written;
    determineVIOAccess(i.instr, m_VarNames, &block->context, read, written);
    // record which are read from outside
    for (auto r : read) {
      // if read and not written before in block
      if (already_written.find(r) == already_written.end()) {
        block->in_vars_read.insert(r); // value from prior block is read
      }
    }
    // record which are written to
    already_written.insert(written.begin(), written.end());
    block->out_vars_written.insert(written.begin(), written.end());
    // update global variable use
    for (auto r : read) {
      m_Vars[m_VarNames.at(r)].access = (e_Access)(m_Vars[m_VarNames.at(r)].access | e_ReadOnly);
    }
    for (auto w : written) {
      m_Vars[m_VarNames.at(w)].access = (e_Access)(m_Vars[m_VarNames.at(w)].access | e_WriteOnly);
    }
  }
}

// -------------------------------------------------

void Algorithm::determineVariablesAccess()
{
  // for all blocks
  // TODO: some blocks may never be reached ...
  for (auto& b : m_Blocks) {
    determineVariablesAccess(b);
  }
  // determine variable access for always blocks
  determineVariablesAccess(&m_AlwaysPre);
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
    // variables are always on the right
    if (m_VarNames.find(b.right) != m_VarNames.end()) {
      if (b.dir == e_Left) {
        // add to always block dependency
        m_AlwaysPre.in_vars_read.insert(b.right);
        // set global access
        m_Vars[m_VarNames[b.right]].access = (e_Access)(m_Vars[m_VarNames[b.right]].access | e_ReadOnly);
      } else if (b.dir == e_Right) {
        // add to always block dependency
        m_AlwaysPre.out_vars_written.insert(b.right);
        // set global access
        // -> check prior access
        if (m_Vars[m_VarNames[b.right]].access & e_WriteOnly) {
          reportError(nullptr, b.line, "cannot write to variable '%s' bound to an algorithm or module output", b.right.c_str());
        }
        // -> mark as write-binded
        m_Vars[m_VarNames[b.right]].access = (e_Access)(m_Vars[m_VarNames[b.right]].access | e_WriteBinded);
      } else { // e_BiDir
        sl_assert(b.dir == e_BiDir);
        // -> check prior access
        if ((m_Vars[m_VarNames[b.right]].access & (~e_ReadWriteBinded)) != 0) {
          reportError(nullptr, b.line, "cannot bind variable '%s' on an inout port, it is used elsewhere", b.right.c_str());
        }
        // add to always block dependency
        m_AlwaysPre.in_vars_read.insert(b.right);
        m_AlwaysPre.out_vars_written.insert(b.right);
        // set global access
        m_Vars[m_VarNames[b.right]].access = (e_Access)(m_Vars[m_VarNames[b.right]].access | e_ReadWriteBinded);
      }
    }
  }
  // determine variable access due to algorithm instances clocks and reset
  for (const auto& m : m_InstancedAlgorithms) {
    std::vector<std::string> candidates;
    candidates.push_back(m.second.instance_clock);
    candidates.push_back(m.second.instance_reset);
    for (auto v : candidates) {
      // variables are always on the right
      if (m_VarNames.find(v) != m_VarNames.end()) {
        // add to always block dependency
        m_AlwaysPre.in_vars_read.insert(v);
        // set global access
        m_Vars[m_VarNames[v]].access = (e_Access)(m_Vars[m_VarNames[v]].access | e_ReadOnly);
      }
    }
  }
  // determine variable access due to memories
  for (auto& mem : m_Memories) {
    for (auto& inv : mem.in_vars) {
      // add to always block dependency
      m_AlwaysPre.in_vars_read.insert(inv);
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

}

// -------------------------------------------------

void Algorithm::determineVariablesUsage()
{
  // determine variables access
  determineVariablesAccess();
  // analyze usage
  auto blocks = m_Blocks;
  blocks.push_front(&m_AlwaysPre);
  // merge all in_reads and out_written
  std::unordered_set<std::string> global_in_read;
  std::unordered_set<std::string> global_out_written;
  for (const auto& b : blocks) {
    global_in_read    .insert(b->in_vars_read.begin(), b->in_vars_read.end());
    global_out_written.insert(b->out_vars_written.begin(), b->out_vars_written.end());
  }
  // report
  std::cerr << "---< variables >---" << std::endl;
  for (auto& v : m_Vars) {
    if (v.access == e_ReadOnly) {
      std::cerr << v.name << " => const ";
      v.usage = e_Const;
    } else if (v.access == e_WriteOnly) {
      std::cerr << v.name << " => written but not used ";
      v.usage = e_Temporary; // e_NotUsed;
    } else if (v.access == e_ReadWrite) {
      if (global_in_read.find(v.name) == global_in_read.end()) {
        std::cerr << v.name << " => temp ";
        v.usage = e_Temporary;
      } else {
        std::cerr << v.name << " => flip-flop ";
        v.usage = e_FlipFlop;
      }
    } else if (v.access == (e_WriteBinded | e_ReadOnly)) {
      std::cerr << v.name << " => write-binded ";
      v.usage = e_Bound;
    } else if (v.access == (e_WriteBinded)) {
      std::cerr << v.name << " => write-binded but not used ";
      v.usage = e_Bound;
    } else if (v.access == e_NotAccessed) {
      std::cerr << v.name << " => unused ";
      v.usage = e_NotUsed;
    } else if (v.access == e_ReadWriteBinded) {
      std::cerr << v.name << " => bound to inout ";
      v.usage = e_Bound;
    } else if ((v.access & e_InternalFlipFlop) == e_InternalFlipFlop) {
      std::cerr << v.name << " => internal flip-flop ";
      v.usage = e_FlipFlop;
    } else {
      std::cerr << Console::yellow << "warning: " << v.name << " unexpected usage." << Console::gray << std::endl;
      v.usage = e_FlipFlop;
    }
    std::cerr << std::endl;
  }

#if 0
  /////////// DEBUG
  for (const auto& v : m_Vars) {
    cerr << v.name << " access: ";
    if (v.access & e_ReadOnly) cerr << 'R';
    if (v.access & e_WriteOnly) cerr << 'W';
    std::cerr << std::endl;
  }
  for (const auto& b : blocks) {
    std::cerr << "== block " << b->block_name << "==" << std::endl;
    std::cerr << "   read from before: ";
    for (auto i : b->in_vars_read) {
      std::cerr << i << ' ';
    }
    std::cerr << std::endl;
    std::cerr << "   changed within: ";
    for (auto i : b->out_vars_written) {
      std::cerr << i << ' ';
    }
    std::cerr << std::endl;
  }
  /////////////////
#endif

}

// -------------------------------------------------

void Algorithm::determineModAlgBoundVIO()
{
  // find out vio bound to a module input/output
  for (const auto& im : m_InstancedModules) {
    for (const auto& bi : im.second.bindings) {
      if (bi.dir == e_Right) {
        // record wire name for this output
        m_VIOBoundToModAlgOutputs[bi.right] = WIRE + im.second.instance_prefix + "_" + bi.left;
      } else if (bi.dir == e_BiDir) {
        // record wire name for this inout
        std::string bindpoint = im.second.instance_prefix + "_" + bi.left;
        m_ModAlgInOutsBoundToVIO[bindpoint] = bi.right;
      }
    }
  }
  // find out vio bound to an algorithm output
  for (const auto& ia : m_InstancedAlgorithms) {
    for (const auto& bi : ia.second.bindings) {
      if (bi.dir == e_Right) {
        // record wire name for this output
        m_VIOBoundToModAlgOutputs[bi.right] = WIRE + ia.second.instance_prefix + "_" + bi.left;
      } else if (bi.dir == e_BiDir) {
        // record wire name for this inout
        std::string bindpoint = ia.second.instance_prefix + "_" + bi.left;
        m_ModAlgInOutsBoundToVIO[bindpoint] = bi.right;
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::determineBlockDependencies(const t_combinational_block* block, t_vio_dependencies& _dependencies) const
{
  for (const auto& a : block->instructions) {
    // update dependencies
    updateDependencies(_dependencies, a.instr, &block->context);
  }
}

// -------------------------------------------------

void Algorithm::analyzeInstancedAlgorithmsInputs()
{
  for (auto& ia : m_InstancedAlgorithms) {
    for (const auto& b : ia.second.bindings) {
      if (b.dir == e_Left) { // setting input
        // input is bound directly
        ia.second.boundinputs.insert(std::make_pair(b.left, b.right));
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::analyzeOutputsAccess()
{
  // go through all instructions and determine access
  std::unordered_set<std::string> global_read;
  std::unordered_set<std::string> global_written;
  for (const auto& b : m_Blocks) {
    for (const auto& i : b->instructions) {
      std::unordered_set<std::string> read;
      std::unordered_set<std::string> written;
      determineVIOAccess(i.instr, m_OutputNames, &b->context, read, written);
      global_read.insert(read.begin(), read.end());
      global_written.insert(written.begin(), written.end());
    }
  }
  // always block
  std::unordered_set<std::string> always_read;
  std::unordered_set<std::string> always_written;
  std::vector<t_combinational_block*> ablocks;
  ablocks.push_back(&m_AlwaysPre);
  for (const auto& b : ablocks) {
    for (const auto& i : b->instructions) {
      std::unordered_set<std::string> read;
      std::unordered_set<std::string> written;
      determineVIOAccess(i.instr, m_OutputNames, nullptr, read, written);
      always_read.insert(read.begin(), read.end());
      always_written.insert(written.begin(), written.end());
    }
  }
  // analyze access and usage
  std::cerr << "---< outputs >---" << std::endl;
  for (auto& o : m_Outputs) {
    auto W = m_VIOBoundToModAlgOutputs.find(o.name);
    if (W != m_VIOBoundToModAlgOutputs.end()) {
      // bound to a wire
      if (global_written.find(o.name) != global_written.end()) {
        // NOTE: always caught before? (see determineVariablesAccess)
        reportError(nullptr, -1, (std::string("cannot write to an output bound to a module/algorithm (") + o.name + ")").c_str());
      }
      if (always_written.find(o.name) != always_written.end()) {
        // NOTE: always caught before? (see determineVariablesAccess)
        reportError(nullptr, -1, (std::string("cannot write to an output bound to a module/algorithm (") + o.name + ")").c_str());
      }
      o.usage = e_Bound;
      std::cerr << o.name << " => wire" << std::endl;
    } else if (
      global_written.find(o.name) == global_written.end()
      && global_read.find(o.name) == global_read.end()
      && (always_written.find(o.name) != always_written.end()
        || always_read.find(o.name) != always_read.end()
        )
      ) {
      // not used in blocks but used in always block
      // only assigned (either way)
      // o.usage = e_Assigned; /////// TODO
      o.usage = e_FlipFlop;
      std::cerr << o.name << " => assigned" << std::endl;
    } else {
      // any other case: flip-flop
      // NOTE: outputs are always considered used externally (read)
      //       they also have to be set at each step of the algorithm (avoiding latches)
      //       thus as soon as used in a block != always, they become flip-flops
      o.usage = e_FlipFlop;
      std::cerr << o.name << " => flip-flop" << std::endl;
    }
  }
}

// -------------------------------------------------

Algorithm::Algorithm(
  std::string name, 
  std::string clock, std::string reset, bool autorun, int stack_size,
  const std::unordered_map<std::string, AutoPtr<Module> >& known_modules,
  const std::unordered_map<std::string, siliceParser::SubroutineContext*>& known_subroutines,
  const std::unordered_map<std::string, siliceParser::CircuitryContext*>&  known_circuitries,
  const std::unordered_map<std::string, siliceParser::GroupContext*>& known_groups
)
  : m_Name(name), m_Clock(clock), 
  m_Reset(reset), m_AutoRun(autorun), m_StackSize(stack_size),
  m_KnownModules(known_modules), m_KnownSubroutines(known_subroutines), 
  m_KnownCircuitries(known_circuitries), m_KnownGroups(known_groups)
{
  // init with empty always blocks
  m_AlwaysPre.id = 0;
  m_AlwaysPre.block_name = "_always_pre";
}

// -------------------------------------------------

void Algorithm::gather(siliceParser::InOutListContext *inout, antlr4::tree::ParseTree *declAndInstr)
{
  // gather elements from source code
  t_combinational_block *main = addBlock("_top", nullptr, (int)inout->getStart()->getLine());
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

void Algorithm::optimize()
{
  // check bindings
  checkModulesBindings();
  checkAlgorithmsBindings();
  // determine which VIO are assigned to wires
  determineModAlgBoundVIO();
  // analyze variables access 
  determineVariablesUsage();
  // analyze outputs access
  analyzeOutputsAccess();
  // analyze instanced algorithms inputs
  analyzeInstancedAlgorithmsInputs();
}

// -------------------------------------------------

std::tuple<Algorithm::e_Type, int, int> Algorithm::determineVIOTypeWidthAndTableSize(const t_combinational_block_context *bctx, std::string vname,int line) const
{
  // get width
  e_Type type = Int;
  int width = -1;
  int table_size = 0;
  // translate
  vname = translateVIOName(vname, bctx);
  // test if variable
  if (m_VarNames.find(vname) != m_VarNames.end()) {
    type = m_Vars[m_VarNames.at(vname)].base_type;
    width = m_Vars[m_VarNames.at(vname)].width;
    table_size = m_Vars[m_VarNames.at(vname)].table_size;
  } else if (m_InputNames.find(vname) != m_InputNames.end()) {
    type = m_Inputs[m_InputNames.at(vname)].base_type;
    width = m_Inputs[m_InputNames.at(vname)].width;
    table_size = m_Inputs[m_InputNames.at(vname)].table_size;
  } else if (m_OutputNames.find(vname) != m_OutputNames.end()) {
    type = m_Outputs[m_OutputNames.at(vname)].base_type;
    width = m_Outputs[m_OutputNames.at(vname)].width;
    table_size = m_Outputs[m_OutputNames.at(vname)].table_size;
  } else {
    reportError(nullptr, line, "variable '%s' not yet declared", vname.c_str());
  }
  return std::make_tuple(type, width, table_size);
}

// -------------------------------------------------

std::tuple<Algorithm::e_Type, int, int> Algorithm::determineIdentifierTypeWidthAndTableSize(const t_combinational_block_context *bctx, antlr4::tree::TerminalNode *identifier, int line) const
{
  sl_assert(identifier != nullptr);
  std::string vname = identifier->getText();
  return determineVIOTypeWidthAndTableSize(bctx, vname, line);
}

// -------------------------------------------------

std::pair<Algorithm::e_Type, int> Algorithm::determineIdentifierTypeAndWidth(const t_combinational_block_context *bctx, antlr4::tree::TerminalNode *identifier, int line) const
{
  sl_assert(identifier != nullptr);
  auto tws = determineIdentifierTypeWidthAndTableSize(bctx, identifier, line);
  return std::make_pair(std::get<0>(tws), std::get<1>(tws));
}

// -------------------------------------------------

std::pair<Algorithm::e_Type, int> Algorithm::determineIOAccessTypeAndWidth(const t_combinational_block_context *bctx, siliceParser::IoAccessContext* ioaccess) const
{
  sl_assert(ioaccess != nullptr);
  std::string base = ioaccess->base->getText();
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
      return std::make_pair(
        A->second.algo->m_Inputs[A->second.algo->m_InputNames.at(member)].base_type,
        A->second.algo->m_Inputs[A->second.algo->m_InputNames.at(member)].width
      );
    } else if (A->second.algo->isOutput(member)) {
      return std::make_pair(
        A->second.algo->m_Outputs[A->second.algo->m_OutputNames.at(member)].base_type,
        A->second.algo->m_Outputs[A->second.algo->m_OutputNames.at(member)].width
      );
    } else {
      sl_assert(false);
    }
  } else {
    auto B = m_MemoryNames.find(base);
    if (B != m_MemoryNames.end()) {
      const auto& mem = m_Memories[B->second];
      verifyMemberMemory(mem, member, (int)ioaccess->getStart()->getLine());
      // produce the variable name
      std::string vname = base + "_" + member;
      // get width and size
      auto tws = determineVIOTypeWidthAndTableSize(bctx, vname, (int)ioaccess->getStart()->getLine());
      return std::make_pair(std::get<0>(tws), std::get<1>(tws));
    } else {
      reportError(ioaccess->getSourceInterval(), (int)ioaccess->getStart()->getLine(),
        "cannot find accessed member '%s'", base.c_str());
    }
  }
  sl_assert(false);
  return std::make_pair(Int, 0);
}

// -------------------------------------------------

std::pair<Algorithm::e_Type, int> Algorithm::determineBitAccessTypeAndWidth(const t_combinational_block_context *bctx, siliceParser::BitAccessContext *bitaccess) const
{
  sl_assert(bitaccess != nullptr);
  if (bitaccess->IDENTIFIER() != nullptr) {
    return determineIdentifierTypeAndWidth(bctx, bitaccess->IDENTIFIER(), (int)bitaccess->getStart()->getLine());
  } else if (bitaccess->tableAccess() != nullptr) {
    return determineTableAccessTypeAndWidth(bctx, bitaccess->tableAccess());
  } else {
    return determineIOAccessTypeAndWidth(bctx, bitaccess->ioAccess());
  }
}

// -------------------------------------------------

std::pair<Algorithm::e_Type, int> Algorithm::determineTableAccessTypeAndWidth(const t_combinational_block_context *bctx, siliceParser::TableAccessContext *tblaccess) const
{
  sl_assert(tblaccess != nullptr);
  if (tblaccess->IDENTIFIER() != nullptr) {
    return determineIdentifierTypeAndWidth(bctx, tblaccess->IDENTIFIER(), (int)tblaccess->getStart()->getLine());
  } else {
    return determineIOAccessTypeAndWidth(bctx, tblaccess->ioAccess());
  }
}

// -------------------------------------------------

std::pair<Algorithm::e_Type, int> Algorithm::determineAccessTypeAndWidth(const t_combinational_block_context *bctx, siliceParser::AccessContext *access, antlr4::tree::TerminalNode *identifier) const
{
  if (access) {
    // table, output or bits
    if (access->ioAccess() != nullptr) {
      return determineIOAccessTypeAndWidth(bctx,access->ioAccess());
    } else if (access->tableAccess() != nullptr) {
      return determineTableAccessTypeAndWidth(bctx,access->tableAccess());
    } else if (access->bitAccess() != nullptr) {
      return determineBitAccessTypeAndWidth(bctx,access->bitAccess());
    }
  } else {
    // identifier
    return determineIdentifierTypeAndWidth(bctx, identifier, (int)identifier->getSymbol()->getLine());
  }
  sl_assert(false);
  return std::make_pair(Int, 0);
}

// -------------------------------------------------

void Algorithm::writeAlgorithmCall(antlr4::tree::ParseTree *node, std::string prefix, std::ostream& out, const t_algo_nfo& a, siliceParser::ParamListContext* plist, const t_combinational_block_context *bctx, const t_vio_dependencies& dependencies) const
{
  // check for clock domain crossing
  if (a.instance_clock != m_Clock) {
    reportError(node->getSourceInterval(),(int)plist->getStart()->getLine(),
      "algorithm instance '%s' called accross clock-domain -- not yet supported",
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
        "algorithm instance '%s' cannot be called as its input '%s' is bound",
          a.instance_name.c_str(), ins.name.c_str());
      }
      out << FF_D << a.instance_prefix << "_" << ins.name
        << " = " << rewriteExpression(prefix, params[p++], -1 /*cannot be in repeated block*/, bctx, dependencies) 
        << ";" << std::endl;
    }
  }
  // restart algorithm (pulse run low)
  out << a.instance_prefix << "_" << ALG_RUN << " = 0;" << std::endl;
  /// WARNING: this does not work across clock domains!
}

// -------------------------------------------------

void Algorithm::writeAlgorithmReadback(antlr4::tree::ParseTree *node, std::string prefix, std::ostream& out, const t_algo_nfo& a, siliceParser::AssignListContext* plist, const t_combinational_block_context* bctx) const
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
        writeAccess(prefix, out, true, plist->assign()[p]->access(), -1, bctx, _);
      } else {
        out << rewriteIdentifier(prefix, plist->assign()[p]->IDENTIFIER()->getText(), bctx, plist->getStart()->getLine(), FF_D);
      }
      out << " = " << WIRE << a.instance_prefix << "_" << outs.name << ";" << std::endl;
      ++p;
    }
  }
}

// -------------------------------------------------

void Algorithm::writeSubroutineCall(antlr4::tree::ParseTree *node, std::string prefix, std::ostream& out, const t_subroutine_nfo *called, const t_combinational_block_context *bctx, siliceParser::ParamListContext* plist, const t_vio_dependencies& dependencies) const
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
    // filter out inputs which are not used
    const auto& info = m_Vars[m_VarNames.at(called->vios.at(ins))];
    if (info.access == e_WriteOnly) {
      p++;
      continue;
    }
    out << FF_D << prefix << called->vios.at(ins)
      << " = " << rewriteExpression(prefix, params[p++], -1 /*cannot be in repeated block*/, bctx, dependencies)
      << ';' << std::endl;
  }
}

// -------------------------------------------------

void Algorithm::writeSubroutineReadback(antlr4::tree::ParseTree *node, std::string prefix, std::ostream& out, const t_subroutine_nfo* called, const t_combinational_block_context* bctx, siliceParser::AssignListContext* plist) const
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
      writeAccess(prefix, out, true, plist->assign()[p]->access(), -1, bctx, _);
    } else {
      out << rewriteIdentifier(prefix, plist->assign()[p]->IDENTIFIER()->getText(), bctx, plist->getStart()->getLine(), FF_D);
    }
    out << " = " << FF_D << prefix << called->vios.at(outs) << ';' << std::endl;
    ++p;
  }
}

// -------------------------------------------------

std::tuple<Algorithm::e_Type, int, int> Algorithm::writeIOAccess(
  std::string prefix, std::ostream& out, bool assigning, siliceParser::IoAccessContext* ioaccess,
  int __id,
  const t_combinational_block_context* bctx, const t_vio_dependencies& dependencies) const
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
    auto B = m_MemoryNames.find(base);
    if (B != m_MemoryNames.end()) {
      const auto& mem = m_Memories[B->second];
      verifyMemberMemory(mem, member, (int)ioaccess->getStart()->getLine());
      // produce the variable name
      std::string vname = base + "_" + member;
      // write
      out << rewriteIdentifier(prefix, vname, bctx, (int)ioaccess->getStart()->getLine(), assigning ? FF_D : FF_Q, dependencies);
      return determineVIOTypeWidthAndTableSize(bctx, vname, (int)ioaccess->getStart()->getLine());
    } else {
      auto G = m_VIOGroups.find(base);
      if (G != m_VIOGroups.end()) {
        verifyMemberGroup(member,G->second, (int)ioaccess->getStart()->getLine());
        // produce the variable name
        std::string vname = base + "_" + member;
        // write
        out << rewriteIdentifier(prefix, vname, bctx, (int)ioaccess->getStart()->getLine(), assigning ? FF_D : FF_Q, dependencies);
        return determineVIOTypeWidthAndTableSize(bctx, vname, (int)ioaccess->getStart()->getLine());
      } else {
        reportError(ioaccess->getSourceInterval(), (int)ioaccess->getStart()->getLine(),
          "cannot find accessed base.member '%s.%s'", base.c_str(), member.c_str());
      }
    }
  }
  sl_assert(false);
  return make_tuple(UInt,0,0);
}

// -------------------------------------------------

void Algorithm::writeTableAccess(
  std::string prefix, std::ostream& out, bool assigning,
  siliceParser::TableAccessContext* tblaccess, 
  int __id, 
  const t_combinational_block_context *bctx, const t_vio_dependencies& dependencies) const
{
  if (tblaccess->ioAccess() != nullptr) {
    auto tws = writeIOAccess(prefix, out, assigning, tblaccess->ioAccess(), __id, bctx, dependencies);
    if (get<2>(tws) == 0) {
      reportError(tblaccess->ioAccess()->IDENTIFIER().back()->getSymbol(), (int)tblaccess->getStart()->getLine(), "trying to access a non table as a table");
    }
    out << "[(" << rewriteExpression(prefix, tblaccess->expression_0(), __id, bctx, dependencies) << ")*" << get<1>(tws) << "+:" << get<1>(tws) << ']';
  } else {
    sl_assert(tblaccess->IDENTIFIER() != nullptr);
    std::string vname = tblaccess->IDENTIFIER()->getText();
    out << rewriteIdentifier(prefix, vname, bctx, tblaccess->getStart()->getLine(), assigning ? FF_D : FF_Q, dependencies);
    // get width
    auto tws = determineIdentifierTypeWidthAndTableSize(bctx, tblaccess->IDENTIFIER(), (int)tblaccess->getStart()->getLine());
    if (get<2>(tws) == 0) {
      reportError(tblaccess->IDENTIFIER()->getSymbol(), (int)tblaccess->getStart()->getLine(), "trying to access a non table as a table");
    }
    // TODO: if the expression can be evaluated at compile time, we could check for access validity using table_size
    out << "[(" << rewriteExpression(prefix, tblaccess->expression_0(), __id, bctx, dependencies) << ")*" << std::get<1>(tws) << "+:" << std::get<1>(tws) << ']';
  }
}

// -------------------------------------------------

void Algorithm::writeBitAccess(std::string prefix, std::ostream& out, bool assigning, siliceParser::BitAccessContext* bitaccess, int __id, const t_combinational_block_context* bctx, const t_vio_dependencies& dependencies) const
{
  // TODO: check access validity
  if (bitaccess->ioAccess() != nullptr) {
    writeIOAccess(prefix, out, assigning, bitaccess->ioAccess(), __id, bctx, dependencies);
  } else if (bitaccess->tableAccess() != nullptr) {
    writeTableAccess(prefix, out, assigning, bitaccess->tableAccess(), __id, bctx, dependencies);
  } else {
    sl_assert(bitaccess->IDENTIFIER() != nullptr);
    out << rewriteIdentifier(prefix, bitaccess->IDENTIFIER()->getText(), bctx, bitaccess->getStart()->getLine(), assigning ? FF_D : FF_Q, dependencies);
  }
  out << '[' << rewriteExpression(prefix, bitaccess->first, __id, bctx, dependencies) << "+:" << bitaccess->num->getText() << ']';
}

// -------------------------------------------------

void Algorithm::writeAccess(std::string prefix, std::ostream& out, bool assigning, siliceParser::AccessContext* access, int __id, const t_combinational_block_context* bctx, const t_vio_dependencies& dependencies) const
{
  if (access->ioAccess() != nullptr) {
    writeIOAccess(prefix, out, assigning, access->ioAccess(), __id, bctx, dependencies);
  } else if (access->tableAccess() != nullptr) {
    writeTableAccess(prefix, out, assigning, access->tableAccess(), __id, bctx, dependencies);
  } else if (access->bitAccess() != nullptr) {
    writeBitAccess(prefix, out, assigning, access->bitAccess(), __id, bctx, dependencies);
  }
}

// -------------------------------------------------

void Algorithm::writeAssignement(std::string prefix, std::ostream& out,
  const t_instr_nfo& a,
  siliceParser::AccessContext *access,
  antlr4::tree::TerminalNode* identifier,
  siliceParser::Expression_0Context *expression_0,
  const t_combinational_block_context *bctx,
  const t_vio_dependencies& dependencies) const
{
  if (access) {
    // table, output or bits
    writeAccess(prefix, out, true, access, a.__id, bctx, dependencies);
  } else {
    sl_assert(identifier != nullptr);
    // variable
    if (isInput(identifier->getText())) {
      reportError(a.instr->getSourceInterval(), (int)identifier->getSymbol()->getLine(),
        "cannot assign a value to an input of the algorithm, input '%s'",
        identifier->getText().c_str());
    }
    out << rewriteIdentifier(prefix, identifier->getText(), bctx, identifier->getSymbol()->getLine(), FF_D);
  }
  out << " = " + rewriteExpression(prefix, expression_0, a.__id, bctx, dependencies);
  out << ';' << std::endl;

}

// -------------------------------------------------

void Algorithm::writeBlock(std::string prefix, std::ostream& out, const t_combinational_block* block, t_vio_dependencies& _dependencies) const
{
  out << "// " << block->block_name;
  if (block->context.subroutine) {
    out << " (" << block->context.subroutine->name << ')';
  }
  out << std::endl;
  // if this is a subroutine first block, write local vars init
  if (block->context.subroutine != nullptr) {
    if (!strncmp(block->block_name.c_str(), SUB_ENTRY_BLOCK, strlen(SUB_ENTRY_BLOCK))) {
      t_vio_dependencies _;
      out << "// sub locals init" << std::endl;
      writeVarInits(prefix, out, block->context.subroutine->varnames, _);
      out << "// --" << std::endl;
    }
  }
  for (const auto& a : block->instructions) {
    // write instruction
    {
      auto assign = dynamic_cast<siliceParser::AssignmentContext*>(a.instr);
      if (assign) {
        writeAssignement(prefix, out, a, assign->access(), assign->IDENTIFIER(), assign->expression_0(), &block->context, _dependencies);
      }
    } {
      auto alw = dynamic_cast<siliceParser::AlwaysAssignedContext*>(a.instr);
      if (alw) {
        if (alw->ALWSASSIGNDBL() != nullptr) {
          std::ostringstream ostr;
          writeAssignement(prefix, ostr, a, alw->access(), alw->IDENTIFIER(), alw->expression_0(), &block->context, _dependencies);
          // modify assignement to insert temporary var
          std::size_t pos = ostr.str().find('=');
          std::string lvalue = ostr.str().substr(0, pos - 1);
          std::string rvalue = ostr.str().substr(pos + 1);
          std::string tmpvar = "_delayed_" + std::to_string(alw->getStart()->getLine()) + "_" + std::to_string(alw->getStart()->getCharPositionInLine());
          out << lvalue << " = " << FF_D << tmpvar << ';' << std::endl;
          out << FF_D << tmpvar << " = " << rvalue; // rvalue includes the line end ";\n"
        } else {
          writeAssignement(prefix, out, a, alw->access(), alw->IDENTIFIER(), alw->expression_0(), &block->context, _dependencies);
        }
      }
    } {
      auto display = dynamic_cast<siliceParser::DisplayContext *>(a.instr);
      if (display) {
        out << "$display(" << display->STRING()->getText();
        if (display->displayParams() != nullptr) {
          for (auto p : display->displayParams()->IDENTIFIER()) {
            out << "," << rewriteIdentifier(prefix, p->getText(), &block->context, display->getStart()->getLine(), FF_Q, _dependencies);
          }
        }
        out << ");" << std::endl;
      }
    } {
      auto async = dynamic_cast<siliceParser::AsyncExecContext*>(a.instr);
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
          writeAlgorithmCall(a.instr, prefix, out, A->second, async->paramList(), &block->context, _dependencies);
        }
      }
    } {
      auto sync = dynamic_cast<siliceParser::SyncExecContext*>(a.instr);
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
            writeSubroutineCall(a.instr, prefix, out, S->second, &block->context, sync->paramList(), _dependencies);
          }
        } else {
          writeAlgorithmCall(a.instr, prefix, out, A->second, sync->paramList(), &block->context, _dependencies);
        }
      }
    } {
      auto join = dynamic_cast<siliceParser::JoinExecContext*>(a.instr);
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
            writeSubroutineReadback(a.instr, prefix, out, S->second, &block->context, join->assignList());
          }
        } else {
          writeAlgorithmReadback(a.instr, prefix, out, A->second, join->assignList(), &block->context);
        }
      }
    }
    // update dependencies
    updateDependencies(_dependencies, a.instr, &block->context);
  }
}

// -------------------------------------------------

void Algorithm::writeVarFlipFlopInit(std::string prefix, std::ostream& out, const t_var_nfo& v) const
{
  out << FF_Q << prefix << v.name << " <= " << v.init_values[0] << ';' << std::endl;
}

// -------------------------------------------------

void Algorithm::writeVarFlipFlopUpdate(std::string prefix, std::ostream& out, const t_var_nfo& v) const
{
  out << FF_Q << prefix << v.name << " <= " << FF_D << prefix << v.name << ';' << std::endl;
}

// -------------------------------------------------

int Algorithm::varBitDepth(const t_var_nfo& v) const
{
  if (v.table_size == 0) {
    return v.width;
  } else {
    return v.width * v.table_size;
  }
}

// -------------------------------------------------

std::string Algorithm::typeString(const t_var_nfo& v) const
{
  return typeString(v.base_type);
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
    if (v.usage != e_Const) {
      continue;
    }
    out << "wire " << typeString(v) << " [" << varBitDepth(v) - 1 << ":0] " << FF_CST << prefix << v.name << ';' << std::endl;
    if (v.table_size == 0) {
      out << "assign " << FF_CST << prefix << v.name << " = " << v.init_values[0] << ';' << std::endl;
    } else {
      int width = v.width;
      ForIndex(i, v.table_size) {
        out << "assign " << FF_CST << prefix << v.name << '[' << (i*width) << "+:" << width << ']' << " = " << v.init_values[i] << ';' << std::endl;
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::writeTempDeclarations(std::string prefix, std::ostream& out) const
{
  for (const auto& v : m_Vars) {
    if (v.usage != e_Temporary) continue;
    out << "reg " << typeString(v) << " [" << varBitDepth(v) - 1 << ":0] " << FF_TMP << prefix << v.name << ';' << std::endl;
  }
}

// -------------------------------------------------

void Algorithm::writeWireDeclarations(std::string prefix, std::ostream& out) const
{
  for (const auto& v : m_Vars) {
    if (v.usage != e_Bound || v.access != e_ReadWriteBinded) continue;
    out << "wire " << typeString(v) << " [" << varBitDepth(v) - 1 << ":0] " << WIRE << prefix << v.name << ';' << std::endl;
  }
}

// -------------------------------------------------

void Algorithm::writeFlipFlopDeclarations(std::string prefix, std::ostream& out) const
{
  out << std::endl;
  // flip-flops for vars
  for (const auto& v : m_Vars) {
    if (v.usage != e_FlipFlop) continue;
    out << "reg " << typeString(v) << " [" << varBitDepth(v) - 1 << ":0] ";
    out << FF_D << prefix << v.name << ';' << std::endl;
    if (!v.attribs.empty()) {
      out << v.attribs << std::endl;
    }
    out << "reg " << typeString(v) << " [" << varBitDepth(v) - 1 << ":0] ";
    out << FF_Q << prefix << v.name << ';' << std::endl;
  }
  // flip-flops for outputs
  for (const auto& v : m_Outputs) {
    if (v.usage == e_FlipFlop) {
      out << "reg " << typeString(v) << " [" << varBitDepth(v) - 1 << ":0] ";
      out << FF_D << prefix << v.name << ',' << FF_Q << prefix << v.name << ';' << std::endl;
    }
  }
  // flip-flops for algorithm inputs that are not bound
  for (const auto &ia : m_InstancedAlgorithms) {
    for (const auto &is : ia.second.algo->m_Inputs) {
      if (ia.second.boundinputs.count(is.name) == 0) {
        out << "reg " << typeString(is) << " [" << varBitDepth(is) - 1 << ":0] ";
        out << FF_D << ia.second.instance_prefix << '_' << is.name << ',' << FF_Q << ia.second.instance_prefix << '_' << is.name << ';' << std::endl;
      }
    }
  }
  // state machine index
  out << "reg  [" << stateWidth()-1 << ":0] " FF_D << prefix << ALG_IDX "," FF_Q << prefix << ALG_IDX << ';' << std::endl;
  // state machine return (subroutine)
  out << "reg  [" << ((stateWidth()*m_StackSize)-1) << ":0] " FF_D << prefix << ALG_RETURN << "," FF_Q << prefix << ALG_RETURN << ";" << std::endl;
  out << "reg  [" << ((1 << justHigherPow2(m_StackSize))-1) << ":0]" FF_D << prefix << ALG_RETURN_PTR << ", " FF_Q << prefix << ALG_RETURN_PTR << ';' << std::endl;
  // state machine run for instanced algorithms
  for (const auto& ia : m_InstancedAlgorithms) {
    out << "reg  " << ia.second.instance_prefix + "_" ALG_RUN << ';' << std::endl;
  }
}

// -------------------------------------------------

void Algorithm::writeFlipFlops(std::string prefix, std::ostream& out) const
{
  // output flip-flop init and update on clock
  out << std::endl;
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

  out << "always @(posedge " << clock << ") begin" << std::endl;

  /// init on hardware reset
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
  out << "  if (" << reset << " || !in_run) begin" << std::endl;
  for (const auto& v : m_Vars) {
    if (v.usage != e_FlipFlop) continue;
    writeVarFlipFlopInit(prefix, out, v);
  }
  for (const auto& v : m_Outputs) {
    if (v.usage == e_FlipFlop) {
      writeVarFlipFlopInit(prefix, out, v);
    }
  }
  for (const auto &ia : m_InstancedAlgorithms) {
    for (const auto &is : ia.second.algo->m_Inputs) {
      if (ia.second.boundinputs.count(is.name) == 0) {
        writeVarFlipFlopInit(ia.second.instance_prefix + '_', out, is);
      }
    }
  }
  // state machine 
  // -> on reset
  out << "  if (" << reset << ") begin" << std::endl;
  if (!m_AutoRun) {
    // no autorun: jump to halt state
    out << FF_Q << prefix << ALG_IDX   " <= " << terminationState() << ";" << std::endl;
  } else {
    // autorun: jump to first state
    out << FF_Q << prefix << ALG_IDX   " <= " << entryState() << ";" << std::endl;
  }
  out << "end else begin" << std::endl;
  // -> on restart, jump to first state
  out << FF_Q << prefix << ALG_IDX   " <= " << entryState() << ";" << std::endl;
  out << "end" << std::endl;
  // return index for subroutines
  out << FF_Q << prefix << ALG_RETURN " <= 0;" << std::endl;
  out << FF_Q << prefix << ALG_RETURN_PTR " <= 0;" << std::endl;
  /// updates on clockpos
  out << "  end else begin" << std::endl;
  for (const auto& v : m_Vars) {
    if (v.usage != e_FlipFlop) continue;
    writeVarFlipFlopUpdate(prefix, out, v);
  }
  for (const auto& v : m_Outputs) {
    if (v.usage == e_FlipFlop) {
      writeVarFlipFlopUpdate(prefix, out, v);
    }
  }
  for (const auto &ia : m_InstancedAlgorithms) {
    for (const auto &is : ia.second.algo->m_Inputs) {
      if (ia.second.boundinputs.count(is.name) == 0) {
        writeVarFlipFlopUpdate(ia.second.instance_prefix + '_', out, is);
      }
    }
  }
  // state machine index
  out << FF_Q << prefix << ALG_IDX " <= " FF_D << prefix << ALG_IDX << ';' << std::endl;
  // state machine return
  out << FF_Q << prefix << ALG_RETURN " <= " FF_D << prefix << ALG_RETURN ";" << std::endl;
  out << FF_Q << prefix << ALG_RETURN_PTR " <= " FF_D << prefix << ALG_RETURN_PTR << ';' << std::endl;
  out << "  end" << std::endl;
  out << "end" << std::endl;
}

// -------------------------------------------------

void Algorithm::writeVarFlipFlopCombinationalUpdate(std::string prefix, std::ostream& out, const t_var_nfo& v) const
{
  out << FF_D << prefix << v.name << " = " << FF_Q << prefix << v.name << ';' << std::endl;
}

// -------------------------------------------------

void Algorithm::writeCombinationalAlwaysPre(std::string prefix, std::ostream& out, t_vio_dependencies& _always_dependencies) const
{
  // flip-flops
  for (const auto& v : m_Vars) {
    if (v.usage != e_FlipFlop) continue;
    writeVarFlipFlopCombinationalUpdate(prefix, out, v);
  }
  for (const auto& v : m_Outputs) {
    if (v.usage == e_FlipFlop) {
      writeVarFlipFlopCombinationalUpdate(prefix, out, v);
    }
  }
  for (const auto &ia : m_InstancedAlgorithms) {
    for (const auto &is : ia.second.algo->m_Inputs) {
      if (ia.second.boundinputs.count(is.name) == 0) {
        writeVarFlipFlopCombinationalUpdate(ia.second.instance_prefix + '_', out, is);
      }
    }
  }
  // state machine index
  out << FF_D << prefix << ALG_IDX " = " FF_Q << prefix << ALG_IDX << ';' << std::endl;
  // return stack
  out << FF_D << prefix << ALG_RETURN " = " FF_Q << prefix << ALG_RETURN ";" << std::endl;
  out << FF_D << prefix << ALG_RETURN_PTR " = " FF_Q << prefix << ALG_RETURN_PTR << ';' << std::endl;
  // instanced algorithms run, maintain high
  for (auto ia : m_InstancedAlgorithms) {
    out << ia.second.instance_prefix + "_" ALG_RUN " = 1;" << std::endl;
  }
  // instanced modules input/output bindings with wires
  // NOTE: could this be done with assignements (see Algorithm::writeAsModule) ?
  for (auto im : m_InstancedModules) {
    for (auto b : im.second.bindings) {
      if (b.dir == e_Right) { // output
        if (m_VarNames.find(b.right) != m_VarNames.end()) {
          // bound to variable, the variable is replaced by the output wire
          auto usage = m_Vars.at(m_VarNames.at(b.right)).usage;
          sl_assert(usage == e_Bound);
        } else if (m_OutputNames.find(b.right) != m_OutputNames.end()) {
          // bound to an algorithm output
          auto usage = m_Outputs.at(m_OutputNames.at(b.right)).usage;
          if (usage == e_FlipFlop) {
            out << FF_D << prefix + b.right + " = " + WIRE + im.second.instance_prefix + "_" + b.left << ';' << std::endl;
          }
        }
      }
    }
  }
  // instanced algorithms input/output bindings with wires
  // NOTE: could this be done with assignements (see Algorithm::writeAsModule) ?
  for (auto ia : m_InstancedAlgorithms) {
    for (auto b : ia.second.bindings) {
      if (b.dir == e_Right) { // output
        if (m_VarNames.find(b.right) != m_VarNames.end()) {
          // bound to variable, the variable is replaced by the output wire
          auto usage = m_Vars.at(m_VarNames.at(b.right)).usage;
          sl_assert(usage == e_Bound);
        } else if (m_OutputNames.find(b.right) != m_OutputNames.end()) {
          // bound to an algorithm output
          auto usage = m_Outputs.at(m_OutputNames.at(b.right)).usage;
          if (usage == e_FlipFlop) {
            // the output is a flip-flop, copy from the wire
            out << FF_D << prefix + b.right + " = " + WIRE + ia.second.instance_prefix + "_" + b.left << ';' << std::endl;
          }
          // else, the output is replaced by the wire
        }
      }
    }
  }
  // always block
  std::queue<size_t> q;
  writeStatelessBlockGraph(prefix,out, &m_AlwaysPre,nullptr,q,_always_dependencies);
  // reset temp variables (to ensure no latch is created)
  for (const auto& v : m_Vars) {
    if (v.usage != e_Temporary) continue;
    out << FF_TMP << prefix << v.name << " = 0;" << std::endl;
  }
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

void Algorithm::writeStatelessBlockGraph(std::string prefix, std::ostream& out, const t_combinational_block* block, const t_combinational_block* stop_at, std::queue<size_t>& _q, t_vio_dependencies& _dependencies) const
{
  // recursive call?
  if (stop_at != nullptr) {
    // if called on a state, index state and stop there
    if (block->is_state) {
      // yes: index the state directly
      out << FF_D << prefix << ALG_IDX " = " << fastForward(block)->state_id << ";" << std::endl;
      pushState(block, _q);
      // return
      return;
    }
  }
  // follow the chain
  const t_combinational_block *current = block;
  while (true) {
    // write current block
    writeBlock(prefix, out, current, _dependencies);
    // goto next in chain
    if (current->next()) {
      current = current->next()->next;
    } else if (current->if_then_else()) {
      out << "if (" << rewriteExpression(prefix, current->if_then_else()->test.instr, current->if_then_else()->test.__id, &current->context, _dependencies) << ") begin" << std::endl;
      // recurse if
      t_vio_dependencies depds_if = _dependencies;
      writeStatelessBlockGraph(prefix, out, current->if_then_else()->if_next, current->if_then_else()->after, _q, depds_if);
      out << "end else begin" << std::endl;
      // recurse else
      t_vio_dependencies depds_else = _dependencies;
      writeStatelessBlockGraph(prefix, out, current->if_then_else()->else_next, current->if_then_else()->after, _q, depds_else);
      out << "end" << std::endl;
      // merge dependencies
      mergeDependenciesInto(depds_if, _dependencies);
      mergeDependenciesInto(depds_else, _dependencies);
      // follow after?
      if (current->if_then_else()->after->is_state) {
        return; // no: already indexed by recursive calls
      } else {
        current = current->if_then_else()->after; // yes!
      }
    } else if (current->switch_case()) {
      out << "  case (" << rewriteExpression(prefix, current->switch_case()->test.instr, current->switch_case()->test.__id, &current->context, _dependencies) << ")" << std::endl;
      // recurse block
      t_vio_dependencies depds_before_case = _dependencies;
      for (auto cb : current->switch_case()->case_blocks) {
        out << "  " << cb.first << ": begin" << std::endl;
        // recurse case
        t_vio_dependencies depds_case = depds_before_case;
        writeStatelessBlockGraph(prefix, out, cb.second, current->switch_case()->after, _q, depds_case);
        // merge sets of written vars
        mergeDependenciesInto(depds_case, _dependencies);
        out << "  end" << std::endl;
      }
      // end of case
      out << "endcase" << std::endl;
      // follow after?
      if (current->switch_case()->after->is_state) {
        return; // no: already indexed by recursive calls
      } else {
        current = current->switch_case()->after; // yes!
      }
    } else if (current->while_loop()) {
      // while
      out << "if (" << rewriteExpression(prefix, current->while_loop()->test.instr, current->while_loop()->test.__id, &current->context, _dependencies) << ") begin" << std::endl;
      writeStatelessBlockGraph(prefix, out, current->while_loop()->iteration, current->while_loop()->after, _q, _dependencies);
      out << "end else begin" << std::endl;
      out << FF_D << prefix << ALG_IDX " = " << fastForward(current->while_loop()->after)->state_id << ";" << std::endl;
      pushState(current->while_loop()->after, _q);
      out << "end" << std::endl;
      return;
    } else if (current->return_from()) {
      // decrease return stack pointer
      out << FF_D << prefix << ALG_RETURN_PTR << " = " << FF_Q << prefix << ALG_RETURN_PTR << " - 1;" << std::endl;
      // return to caller (goes to termination of algorithm is not set)
      out << FF_D << prefix << ALG_IDX " = " << FF_D << prefix << ALG_RETURN "[(" << FF_D << prefix << ALG_RETURN_PTR << "*" << stateWidth() << ")+:" << stateWidth() << "];" << std::endl;
      return;
    } else if (current->goto_and_return_to()) {
      // goto subroutine
      out << FF_D << prefix << ALG_IDX " = " << fastForward(current->goto_and_return_to()->go_to)->state_id << ";" << std::endl;
      pushState(current->goto_and_return_to()->go_to, _q);
      // set return index
      out << FF_D << prefix << ALG_RETURN "[(" << FF_Q << prefix << ALG_RETURN_PTR << "*" << stateWidth() << ")+:" << stateWidth() << "] = " << fastForward(current->goto_and_return_to()->return_to)->state_id << ";" << std::endl;
      // increase return stack pointer
      out << FF_D << prefix << ALG_RETURN_PTR << " = " << FF_Q << prefix << ALG_RETURN_PTR << " + 1;" << std::endl;     
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
        out << "if (" WIRE << A->second.instance_prefix + "_" + ALG_DONE " == 1) begin" << std::endl;
        // yes!
        // -> goto next
        out << FF_D << prefix << ALG_IDX " = " << fastForward(current->wait()->next)->state_id << ";" << std::endl;
        pushState(current->wait()->next, _q);
        out << "end else begin" << std::endl;
        // no!
        // -> wait
        out << FF_D << prefix << ALG_IDX " = " << fastForward(current->wait()->waiting)->state_id << ";" << std::endl;
        pushState(current->wait()->waiting, _q);
        out << "end" << std::endl;
      }
      return;
    } else if (current->pipeline_next()) {
      // write pipeline
      current = writeStatelessPipeline(prefix,out,current, _q,_dependencies);
    } else {
      // no action: jump to terminal state
      out << FF_D << prefix << ALG_IDX " = " << terminationState() << ";" << std::endl;
      return;
    }
    // check whether next is a state
    if (current->is_state) {
      // yes: index and stop
      out << FF_D << prefix << ALG_IDX " = " << fastForward(current)->state_id << ";" << std::endl;
      pushState(current, _q);
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
  std::queue<size_t>& _q, t_vio_dependencies& _dependencies) const
{
  // follow the chain
  out << "// pipeline" << std::endl;
  const t_combinational_block *current = block_before->pipeline_next()->next;
  const t_combinational_block *after   = block_before->pipeline_next()->after;
  const t_pipeline_nfo        *pip     = current->context.pipeline->pipeline;
  sl_assert(pip != nullptr);
  while (true) {
    sl_assert(pip == current->context.pipeline->pipeline);
    // write stage
    int stage = current->context.pipeline->stage_id;
    out << "// stage " << stage << std::endl;
    // write code
    t_vio_dependencies deps;
    if (current != after) { // this is the more complex case of multiple blocks in stage
      writeStatelessBlockGraph(prefix, out, current, after, _q, deps); // NOTE: q will not be changed since this is a combinational block
      current = after;
    } else {
      writeBlock(prefix, out, current, deps);
    }
    // trickle vars
    for (auto tv : pip->trickling_vios) {
      if (stage >= tv.second[0] && stage < tv.second[1]) {
        out << FF_D << prefix << tricklingVIOName(tv.first, pip, stage + 1)
          << " = ";
        std::string tricklingsrc = tricklingVIOName(tv.first, pip, stage);
        if (stage == tv.second[0]) {
          out << rewriteIdentifier(prefix,tv.first,&current->context,-1,FF_D);
        } else {
          out << FF_Q << prefix << tricklingsrc;
        }
        out << ';' << std::endl;
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

void Algorithm::writeVarInits(std::string prefix, std::ostream& out, const std::unordered_map<std::string, int >& varnames, t_vio_dependencies& _dependencies) const
{
  for (const auto& vn : varnames) {
    const auto& v = m_Vars.at(vn.second);
    if (v.usage  != e_FlipFlop)  continue;
    if (v.access == e_WriteOnly) continue;
    _dependencies.dependencies.insert(std::make_pair(v.name, 0));
    if (v.table_size == 0) {
      out << FF_D << prefix << v.name << " = " << v.init_values[0] << ';' << std::endl;
    } else {
      ForIndex(i, v.table_size) {
        out << FF_D << prefix << v.name << "[(" << i << ")*" << v.width << "+:" << v.width << ']' << " = " << v.init_values[i] << ';' << std::endl;
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::writeCombinationalStates(std::string prefix, std::ostream& out, const t_vio_dependencies& always_dependencies) const
{
  std::unordered_set<size_t> produced;
  std::queue<size_t>         q;
  q.push(0); // starts at 0
  // states
  out << "case (" << FF_Q << prefix << ALG_IDX << ")" << std::endl;
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
    out << b->state_id << ": begin" << std::endl;
    // track dependencies, starting with those of always block
    t_vio_dependencies depds = always_dependencies;
    if (b->state_id == entryState()) {
      // entry block starts by variable initialization
      writeVarInits(prefix, out, m_VarNames, depds);
    }
    // write block instructions
    writeStatelessBlockGraph(prefix, out, b, nullptr, q, depds);
    // end of state
    out << "end" << std::endl;
  }
  // initiate termination sequence
  // -> termination state
  {
    out << terminationState() << ": begin // end of " << m_Name << std::endl;
    out << "end" << std::endl;
  }
  // default: internal error, should never happen
  {
    out << "default: begin " << std::endl;
    out << FF_D << prefix << ALG_IDX " = " << terminationState() << ";" << std::endl;
    out << " end" << std::endl;
  }
  out << "endcase" << std::endl;
}

// -------------------------------------------------

void Algorithm::writeModuleMemoryBRAM(std::ostream& out, const t_mem_nfo& bram) const
{
  out << "module M_" << m_Name << "_mem_" << bram.name << '(' << endl;
  for (const auto& inv : bram.in_vars) {
    const auto& v = m_Vars[m_VarNames.at(inv)];
    out << "input " << typeString(v) << " [" << varBitDepth(v) - 1 << ":0] " << ALG_INPUT << '_' << v.name << ',' << endl;
  }
  for (const auto& ouv : bram.out_vars) {
    const auto& v = m_Vars[m_VarNames.at(ouv)];
    out << "output reg " << typeString(v) << " [" << varBitDepth(v) - 1 << ":0] " << ALG_OUTPUT << '_' << v.name << ',' << endl;
  }
  out << "input " ALG_CLOCK << endl;
  out << ");" << endl;

  out << "reg " << typeString(bram.base_type) << " [" << bram.width - 1 << ":0] buffer[" << bram.table_size - 1 << ":0];" << endl;
  out << "always @(posedge " ALG_CLOCK ") begin" << endl;
  out << "  if (" << ALG_INPUT << "_" << bram.name << "_wenable" << ") begin" << endl;
  out << "    buffer[" << ALG_INPUT << "_" << bram.name << "_addr" << "] <= " ALG_INPUT << "_" << bram.name << "_wdata" ";" << endl;
  out << "  end else begin" << endl;
  out << "    " << ALG_OUTPUT << "_" << bram.name << "_rdata" << " <= buffer[" << ALG_INPUT << "_" << bram.name << "_addr" << "];" << endl;
  out << "  end" << endl;
  out << "end" << endl;
  out << "initial begin" << endl;
  ForIndex(v, bram.init_values.size()) {
    out << " buffer[" << v << "] = " << bram.init_values[v] << ';' << endl;
  }
  out << "end" << endl;
  out << "endmodule" << endl;
  out << endl;
}

// -------------------------------------------------

void Algorithm::writeModuleMemoryBROM(std::ostream& out, const t_mem_nfo& bram) const
{
  out << "module M_" << m_Name << "_mem_" << bram.name << '(' << endl;
  for (const auto& inv : bram.in_vars) {
    const auto& v = m_Vars[m_VarNames.at(inv)];
    out << "input " << typeString(v) << " [" << varBitDepth(v) - 1 << ":0] " << ALG_INPUT << '_' << v.name << ',' << endl;
  }
  for (const auto& ouv : bram.out_vars) {
    const auto& v = m_Vars[m_VarNames.at(ouv)];
    out << "output reg " << typeString(v) << " [" << varBitDepth(v) - 1 << ":0] " << ALG_OUTPUT << '_' << v.name << ',' << endl;
  }
  out << "input " ALG_CLOCK << endl;
  out << ");" << endl;

  out << "reg " << typeString(bram.base_type) << " [" << bram.width - 1 << ":0] buffer[" << bram.table_size - 1 << ":0];" << endl;
  out << "always @(posedge " ALG_CLOCK ") begin" << endl;
  out << "   " << ALG_OUTPUT << "_" << bram.name << "_rdata" << " <= buffer[" << ALG_INPUT << "_" << bram.name << "_addr" << "];" << endl;
  out << "end" << endl;
  out << "initial begin" << endl;
  ForIndex(v, bram.init_values.size()) {
    out << " buffer[" << v << "] = " << bram.init_values[v] << ';' << endl;
  }
  out << "end" << endl;
  out << "endmodule" << endl;
  out << endl;
}

#if 0
void Algorithm::writeModuleMemoryBROM(std::ostream& out, const t_mem_nfo& brom) const
{
  out << "module M_" << m_Name << "_mem_" << brom.name << '(' << endl;
  for (const auto& inv : brom.in_vars) {
    const auto& v = m_Vars[m_VarNames.at(inv)];
    out << "input " << typeString(v) << " [" << varBitDepth(v) - 1 << ":0] " << ALG_INPUT << '_' << v.name << ',' << endl;
  }
  for (const auto& ouv : brom.out_vars) {
    const auto& v = m_Vars[m_VarNames.at(ouv)];
    out << "output reg " << typeString(v) << " [" << varBitDepth(v) - 1 << ":0] " << ALG_OUTPUT << '_' << v.name << ',' << endl;
  }
  out << "input " ALG_CLOCK << endl;
  out << ");" << endl;

  out << "always @(posedge " ALG_CLOCK ") begin" << endl;    
  out << "  case (" << ALG_INPUT << "_" << brom.name << "_addr" << ')' << endl;
  int width = justHigherPow2((int)brom.init_values.size());
  ForIndex(v, brom.init_values.size()) {
    out << width << "'d" << v << ":" << ALG_OUTPUT << "_" << brom.name << "_rdata=" << brom.init_values[v] << ';' << endl;
  }
  out << "  endcase" << endl;
  out << "end" << endl;
  out << "endmodule" << endl;
  out << endl;
}
#endif

// -------------------------------------------------

void Algorithm::writeModuleMemory(std::ostream& out, const t_mem_nfo& mem) const
{
  switch (mem.mem_type)     {
  case BRAM: writeModuleMemoryBRAM(out, mem); break;
  case BROM: writeModuleMemoryBROM(out, mem); break;
  default: throw Fatal("internal error (unkown memory type)"); break;
  }
}

// -------------------------------------------------


void Algorithm::writeAsModule(ostream& out) const
{
  out << endl;

  // write memory modules
  for (const auto& mem : m_Memories) {
    writeModuleMemory(out, mem);
  }

  // module header
  out << "module M_" << m_Name << '(' << endl;
  out << "input " ALG_CLOCK "," << endl;
  out << "input " ALG_RESET "," << endl;
  for (const auto& v : m_Inputs) {
    out << "input " << typeString(v) << " [" << varBitDepth(v) - 1 << ":0] " << ALG_INPUT << '_' << v.name << ',' << endl;
  }
  for (const auto& v : m_Outputs) {
    out << "output " << typeString(v) << " [" << varBitDepth(v) - 1 << ":0] " << ALG_OUTPUT << '_' << v.name << ',' << endl;
  }
  for (const auto& v : m_InOuts) {
    out << "inout " << typeString(v) << " [" << varBitDepth(v) - 1 << ":0] " << ALG_INOUT << '_' << v.name << ',' << endl;
  }
  out << "input " << ALG_INPUT << "_" << ALG_RUN << ',' << endl;
  out << "output " << ALG_OUTPUT << "_" << ALG_DONE << endl;
  out << ");" << endl;

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
  for (auto& nfo : m_InstancedAlgorithms) {
    // output wires
    for (const auto& os : nfo.second.algo->m_Outputs) {
      out << "wire " << typeString(os) << " [" << varBitDepth(os) - 1 << ":0] "
        << WIRE << nfo.second.instance_prefix << '_' << os.name << ';' << endl;
    }
    // algorithm done
    out << "wire " << WIRE << nfo.second.instance_prefix << '_' << ALG_DONE << ';' << endl;
  }
  // Memory instantiations (1/2)
  for (const auto& mem : m_Memories) {
    // output wires
    for (const auto& ouv : mem.out_vars) {
      const auto& os = m_Vars[m_VarNames.at(ouv)];
      out << "wire " << typeString(os) << " [" << varBitDepth(os) - 1 << ":0] "
        << WIRE << "_mem_" << os.name << ';' << endl;
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
    if (v.usage == e_FlipFlop) {

      out << "assign " << ALG_OUTPUT << "_" << v.name << " = ";
      if (v.combinational) {
        out << FF_D;
      } else {
        out << FF_Q;
      }
      out << "_" << v.name << ';' << endl;
    } else if (v.usage == e_Bound) {
      out << "assign " << ALG_OUTPUT << "_" << v.name << " = " << m_VIOBoundToModAlgOutputs.at(v.name) << ';' << endl;
    }
  }

  // algorithm done
  out << "assign " << ALG_OUTPUT << "_" << ALG_DONE << " = (" << FF_D << "_" << ALG_IDX << " == " << terminationState() << ");" << endl;

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
      if (b.dir == e_Left) {
        // input
        out << '.' << b.left << '('
          << rewriteIdentifier("_", b.right, nullptr, nfo.second.instance_line, FF_D)
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
          if (isInOut(b.right)) {
            out << '.' << b.left << '(' << ALG_INOUT << "_" << b.right << ")";
          } else {
            out << '.' << b.left << '(' << WIRE << "_" << b.right << ")";
          }
        } else {
          reportError(nullptr,b.line,"cannot find module inout binding '%s'", b.left.c_str());
        }
      }
    }
    out << endl << ");" << endl;
  }

  // algorithm instantiations (2/2) 
  for (auto& nfo : m_InstancedAlgorithms) {
    // algorithm module
    out << "M_" << nfo.second.algo_name << ' ' << nfo.second.instance_name << '(' << endl;
    // clock
    out << '.' << ALG_CLOCK << '(' << rewriteIdentifier("_", nfo.second.instance_clock, nullptr, nfo.second.instance_line, FF_Q) << ")," << endl;
    // reset
    out << '.' << ALG_RESET << '(' << rewriteIdentifier("_", nfo.second.instance_reset, nullptr, nfo.second.instance_line, FF_Q) << ")," << endl;
    // inputs
    for (const auto &is : nfo.second.algo->m_Inputs) {
      out << '.' << ALG_INPUT << '_' << is.name << '(';
      if (nfo.second.boundinputs.count(is.name) > 0) {
        // input is bound, directly map bound VIO
        out << rewriteIdentifier("_", nfo.second.boundinputs.at(is.name), nullptr, nfo.second.instance_line, FF_D);
      } else {
        // input is not bound and assigned in logic, a specifc flip-flop is created for this
        out << FF_D << nfo.second.instance_prefix << "_" << is.name;
      }
      out << ')' << ',' << endl;
    }
    // outputs (wire)
    for (const auto& os : nfo.second.algo->m_Outputs) {
      out << '.'
        << ALG_OUTPUT << '_' << os.name
        << '(' << WIRE << nfo.second.instance_prefix << '_' << os.name << ')';
      out << ',' << endl;
    }
    // inouts (host algorithm inout or wire)
    for (const auto& os : nfo.second.algo->m_InOuts) {
      std::string bindpoint = nfo.second.instance_prefix + "_" + os.name;
      const auto& vio = m_ModAlgInOutsBoundToVIO.find(bindpoint);
      if (vio != m_ModAlgInOutsBoundToVIO.end()) {
        if (isInOut(vio->second)) {
          out << '.' << ALG_INOUT << '_' << os.name << '(' << ALG_INOUT << "_" << vio->second << ")";
        } else {
          out << '.' << ALG_INOUT << '_' << os.name << '(' << WIRE << "_" << vio->second << ")";
        }
        out << ',' << endl;
      } else {
        reportError(nullptr, nfo.second.instance_line, "cannot find algorithm inout binding '%s'", os.name.c_str());
      }
    }
    // done
    out << '.' << ALG_OUTPUT << '_' << ALG_DONE
      << '(' << WIRE << nfo.second.instance_prefix << '_' << ALG_DONE << ')';
    out << ',' << endl;
    // run
    out << '.' << ALG_INPUT << '_' << ALG_RUN
      << '(' << nfo.second.instance_prefix << '_' << ALG_RUN << ')';
    out << endl;
    // end of instantiation      
    out << ");" << endl;
  }
  out << endl;

  // Memory instantiations (2/2)
  for (const auto& mem : m_Memories) {
    // module
    out << "M_" << m_Name << "_mem_" << mem.name << ' ' << mem.name << '(' << endl;
    // clock
    out << '.' << ALG_CLOCK << '(' << m_Clock << ")," << endl;
    // inputs
    for (const auto& inv : mem.in_vars) {
      out << '.' << ALG_INPUT << '_' << inv << '(' << rewriteIdentifier("_", inv, nullptr, mem.line, FF_D)  << ")," << endl;
    }
    // output wires
    for (const auto& ouv : mem.out_vars) {
      out << '.' << ALG_OUTPUT << '_' << ouv << '(' << WIRE << "_mem_" << ouv << ')' << endl;
    }
    // end of instantiation      
    out << ");" << endl;
  }
  out << endl;

  // combinational
  out << "always @* begin" << endl;
  t_vio_dependencies always_dependencies;
  writeCombinationalAlwaysPre("_", out, always_dependencies);
  writeCombinationalStates("_", out, always_dependencies);
  out << "end" << endl;

  out << "endmodule" << endl;
  out << endl;
}

// -------------------------------------------------
