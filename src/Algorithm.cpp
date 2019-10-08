// -------------------------------------------------
//
// Silice FPGA language
//
// (c) Sylvain Lefebvre 2019
// 
//                                ... code hard! ...
// -------------------------------------------------
/*

Algorithm, implementation

*/

// -------------------------------------------------

#include "Algorithm.h"
#include "Module.h"

// -------------------------------------------------

std::string Algorithm::bindingSourceString(std::string source, int decl_line, std::string ff) const
{
  if (source == ALG_RESET || source == ALG_CLOCK) {
    return source;
  } else if (source == m_Reset) { // cannot be ALG_RESET
    return m_VIOBoundToModAlgOutputs.at(source);
  } else if (source == m_Clock) { // cannot be ALG_CLOCK
    return m_VIOBoundToModAlgOutputs.at(source);
  } else if (isInput(source)) {
    return ALG_INPUT "_" + source;
  } else if (isOutput(source)) {
    auto usage = m_Outputs.at(m_OutputNames.at(source)).usage;
    if (usage == e_FlipFlop) {
      return ff + "_" + source;
    } else if (usage == e_Wire) {
      return m_VIOBoundToModAlgOutputs.at(source);
    } else {
      // should be e_Assigned ; currently replaced by a flip-flop but could be avoided
      throw Fatal("assigned outputs: not yet implemented");
    }
  } else {
    if (m_VarNames.find(source) == m_VarNames.end()) {
      throw Fatal("binding source variable '%s' was never declared (line %d)", source.c_str(), decl_line);
    }
    auto usage = m_Vars.at(m_VarNames.at(source)).usage;
    if (usage == e_Wire) {
      return m_VIOBoundToModAlgOutputs.at(source);
    } else {
      return ff + "_" + source;
    }
  }
  throw Fatal("binding source '%s' not found (line %d)", source.c_str(), decl_line);
}

// -------------------------------------------------

void Algorithm::checkModulesBindings() const
{
  for (auto& im : m_InstancedModules) {
    for (const auto& b : im.second.bindings) {
      bool is_input  = (im.second.mod->inputs() .find(b.left) != im.second.mod->inputs() .end());
      bool is_output = (im.second.mod->outputs().find(b.left) != im.second.mod->outputs().end());
      bool is_inout  = (im.second.mod->inouts() .find(b.left) != im.second.mod->inouts() .end());
      if (!is_input && !is_output && !is_inout) {
        throw Fatal("wrong binding point (neither input nor output), instanced module '%s', binding '%s' (line %d)",
          im.first.c_str(), b.left.c_str(), b.line);
      }
      if (b.dir == e_Left && !is_input) { // input
        throw Fatal("wrong binding direction, instanced module '%s', binding output '%s' (line %d)",
          im.first.c_str(), b.left.c_str(), b.line);
      }
      if (b.dir == e_Right && !is_output) { // output
        throw Fatal("wrong binding direction, instanced module '%s', binding input '%s' (line %d)",
          im.first.c_str(), b.left.c_str(), b.line);
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::checkAlgorithmsBindings() const
{
  for (auto& ia : m_InstancedAlgorithms) {
    for (const auto& b : ia.second.bindings) {
      bool is_input  = ia.second.algo->isInput(b.left);
      bool is_output = ia.second.algo->isOutput(b.left);
      if (!is_input && !is_output) {
        throw Fatal("wrong binding point (neither input nor output), instanced module '%s', binding '%s' (line %d)",
          ia.first.c_str(), b.left.c_str(), b.line);
      }
      if (b.dir == e_Left && !is_input) { // input
        throw Fatal("wrong binding direction, instanced module '%s', binding output '%s' (line %d)",
          ia.first.c_str(), b.left.c_str(), b.line);
      }
      if (b.dir == e_Right && !is_output) { // output
        throw Fatal("wrong binding direction, instanced module '%s', binding input '%s' (line %d)",
          ia.first.c_str(), b.left.c_str(), b.line);
      }
    }
  }
}

// -------------------------------------------------

void Algorithm::writeAsModule(ostream& out) const
{
  out << endl;
  
  // module header
  out << "module M_" << m_Name << '(' << endl;
  out << "input " ALG_CLOCK "," << endl;
  out << "input " ALG_RESET "," << endl;
  for (const auto& v : m_Inputs) {
    out << "input [" << varBitDepth(v) - 1 << ":0] " << ALG_INPUT << '_' << v.name << ',' << endl;
  }
  for (const auto& v : m_Outputs) {
    out << "output [" << varBitDepth(v) - 1 << ":0] " << ALG_OUTPUT << '_' << v.name << ',' << endl;
  }
  for (const auto& v : m_InOuts) {
    out << "inout [" << varBitDepth(v) - 1 << ":0] " << ALG_INOUT << '_' << v.name << ',' << endl;
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
      out << "wire[" << varBitDepth(os) - 1 << ":0] " << WIRE << nfo.second.instance_prefix << '_' << os.name << ';' << endl;
    }
    out << "wire " << WIRE << nfo.second.instance_prefix << '_' << ALG_DONE << ';' << endl;
  }

  // const declarations
  writeConstDeclarations("_", out);

  // temporary vars declarations
  writeTempDeclarations("_", out);

  // flip-flops declarations
  writeFlipFlopDeclarations("_", out);

  // assignments
  for (const auto& v : m_Outputs) {
    if (v.usage == e_FlipFlop) {
      out << "assign " << ALG_OUTPUT << "_" << v.name << " = " << FF_D << "_" << v.name << ';' << endl;
    } else if (v.usage == e_Wire) {
      out << "assign " << ALG_OUTPUT << "_" << v.name << " = " << m_VIOBoundToModAlgOutputs.at(v.name) << ';' << endl;
    }
  }
  out << "assign " << ALG_OUTPUT << "_" << ALG_DONE << " = " << FF_D << "_" << ALG_DONE << ';' << endl;
  
  // flip-flop blocks
  writeFlipFlops("_", out);

  out << endl;

  // module instantiations (2/2)
  // -> module instances
  for (auto& nfo : m_InstancedModules) {
    std::string  wire_prefix = WIRE + nfo.second.instance_prefix;
    // output module instantiation
    out << endl;
    out << nfo.second.module_name << ' ' << nfo.second.instance_prefix << " (" << endl;
    bool first = true;
    for (auto b : nfo.second.bindings) {
      if (!first) out << ',' << endl;
      first = false;
      if (b.dir == e_Left) {
        out << '.' << b.left << '(' << bindingSourceString(b.right,b.line) << ")";
      } else if (b.dir == e_Right) {
        out << '.' << b.left << '(' << wire_prefix + "_" + b.left << ")";
      } else {
        sl_assert(b.dir == e_BiDir);
        out << '.' << b.left << '(' << ALG_INOUT "_" << b.left << ")";
      }
    }
    out << endl << ");" << endl;
  }

  // algorithm instantiations (2/2) 
  for (auto& nfo : m_InstancedAlgorithms) {
    // algorithm module
    out << "M_" << nfo.second.algo_name << ' ' << nfo.second.instance_name << '(' << endl;
    // clock
    out << '.' << ALG_CLOCK << '(' << bindingSourceString(nfo.second.instance_clock, nfo.second.instance_line, FF_Q) << ")," << endl;
    // reset
    out << '.' << ALG_RESET << '(' << bindingSourceString(nfo.second.instance_reset, nfo.second.instance_line, FF_Q) << ")," << endl;
    // inputs
    for (const auto& ins : nfo.second.algo->m_Inputs) {
      if (nfo.second.boundinputs.count(ins.name) == 0) {
        out << '.'
          << ALG_INPUT << '_' << ins.name
          << '(' << REG_INPUT << nfo.second.instance_prefix << "_" << ins.name << ')';
        out << ',' << endl;
      }
    }
    // outputs
    for (const auto& os : nfo.second.algo->m_Outputs) {
        out << '.'
          << ALG_OUTPUT << '_' << os.name
          << '(' << WIRE << nfo.second.instance_prefix << '_' << os.name << ')';
        out << ',' << endl;
    }
    // input bindings (output bindings are dealt with in writeCombinationalAlways)
    for (auto b : nfo.second.bindings) {
      if (b.dir == e_Left) {
        out << '.' << ALG_INPUT << '_' << b.left << '(' << bindingSourceString(b.right, b.line) << ")";
        out << ',' << endl;
      }
    }
    // done
    out << '.' << ALG_OUTPUT << '_' << ALG_DONE
      << '(' << WIRE << nfo.second.instance_prefix << '_' << ALG_DONE << ')';
    out << ',' << endl;
    // run
    out << '.' << ALG_INPUT << '_' << ALG_RUN
      << '(' << FF_D << nfo.second.instance_prefix << '_' << ALG_RUN << ')';
    out << endl;
    // end of instantiation      
    out << ");" << endl;
  }

  out << endl;

  // combinational
  out << "always @* begin" << endl;
  writeCombinationalAlways("_", out);
  writeCombinationalStates("_", out);
  out << "end" << endl;

  out << "endmodule" << endl;
  out << endl;
}

// -------------------------------------------------

/// \brief autobind a module
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
        bnfo.right = io.first;
        bnfo.dir   = e_Left;
        _mod.bindings.push_back(bnfo);
      } else // check if algorithm has a var with same name
        if (m_VarNames.find(io.first) != m_VarNames.end()) {
          // yes: autobind
          t_binding_nfo bnfo;
          bnfo.line  = _mod.instance_line;
          bnfo.left  = io.first;
          bnfo.right = io.first;
          bnfo.dir   = e_Left;
          _mod.bindings.push_back(bnfo);
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
        bnfo.line  = _mod.instance_line;
        bnfo.left  = io;
        bnfo.right = io;
        bnfo.dir   = e_Left;
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
        bnfo.line  = _mod.instance_line;
        bnfo.left  = io.first;
        bnfo.right = io.first;
        bnfo.dir   = e_Right;
        _mod.bindings.push_back(bnfo);
      } else // check if algorithm has a var with same name
        if (m_VarNames.find(io.first) != m_VarNames.end()) {
        // yes: autobind
        t_binding_nfo bnfo;
        bnfo.line  = _mod.instance_line;
        bnfo.left  = io.first;
        bnfo.right = io.first;
        bnfo.dir   = e_Right;
        _mod.bindings.push_back(bnfo);
      }
    }
  }
  // -> for each module inout
  for (auto io : _mod.mod->inouts()) {
    if (defined.find(io.first) == defined.end()) {
      // not bound, check if algorithm has an inout with same name
      if (m_InOutNames.find(io.first) != m_InOutNames.end()) {
        // yes: autobind
        t_binding_nfo bnfo;
        bnfo.line  = _mod.instance_line;
        bnfo.left  = io.first;
        bnfo.right = io.first;
        bnfo.dir   = e_BiDir;
        _mod.bindings.push_back(bnfo);
      }
    }
  }
}

/// \brief autobind an algorithm
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
        bnfo.line  = _alg.instance_line;
        bnfo.left  = io.name;
        bnfo.right = io.name;
        bnfo.dir   = e_Left;
        _alg.bindings.push_back(bnfo);
      } else // check if algorithm has a var with same name
        if (m_VarNames.find(io.name) != m_VarNames.end()) {
          // yes: autobind
          t_binding_nfo bnfo;
          bnfo.line  = _alg.instance_line;
          bnfo.left  = io.name;
          bnfo.right = io.name;
          bnfo.dir   = e_Left;
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
        bnfo.line  = _alg.instance_line;
        bnfo.left  = io;
        bnfo.right = io;
        bnfo.dir   = e_Left;
        _alg.bindings.push_back(bnfo);
      }
    }
  }
  // -> for each module output
  for (auto io : _alg.algo->m_Outputs) {
    if (defined.find(io.name) == defined.end()) {
      // not bound, check if host algorithm has an output with same name
      if (m_OutputNames.find(io.name) != m_OutputNames.end()) {
        // yes: autobind
        t_binding_nfo bnfo;
        bnfo.line  = _alg.instance_line;
        bnfo.left  = io.name;
        bnfo.right = io.name;
        bnfo.dir   = e_Right;
        _alg.bindings.push_back(bnfo);
      } else // check if algorithm has a var with same name
        if (m_VarNames.find(io.name) != m_VarNames.end()) {
          // yes: autobind
          t_binding_nfo bnfo;
          bnfo.line  = _alg.instance_line;
          bnfo.left  = io.name;
          bnfo.right = io.name;
          bnfo.dir   = e_Right;
          _alg.bindings.push_back(bnfo);
        }
    }
  }
}

// -------------------------------------------------
