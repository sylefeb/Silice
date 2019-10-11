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
// -------------------------------------------------
//                                ... hardcoding ...
// -------------------------------------------------

#include "Algorithm.h"
#include "Module.h"

using namespace std;
using namespace antlr4;

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
      out << "wire " << typeString(os) << " [" << varBitDepth(os) - 1 << ":0] " << WIRE << nfo.second.instance_prefix << '_' << os.name << ';' << endl;
    }
    // algorithm done
    out << "wire " << WIRE << nfo.second.instance_prefix << '_' << ALG_DONE << ';' << endl;
  }

  // const declarations
  writeConstDeclarations("_", out);

  // temporary vars declarations
  writeTempDeclarations("_", out);

  // flip-flops declarations
  writeFlipFlopDeclarations("_", out);

  // output assignments
  for (const auto& v : m_Outputs) {
    if (v.usage == e_FlipFlop) {
      out << "assign " << ALG_OUTPUT << "_" << v.name << " = " << FF_D << "_" << v.name << ';' << endl;
    } else if (v.usage == e_Bound) {
      out << "assign " << ALG_OUTPUT << "_" << v.name << " = " << m_VIOBoundToModAlgOutputs.at(v.name) << ';' << endl;
    }
  }
  out << "assign " << ALG_OUTPUT << "_" << ALG_DONE << " = (" << FF_D << "_" << ALG_IDX << " == " << terminationState() << ");" << endl;

  // flip-flop blocks
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
        out << '.' << b.left << '(' 
          << prefixIdentifier("_", b.right, nfo.second.instance_line) 
          << ")";
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
    out << '.' << ALG_CLOCK << '(' << prefixIdentifier("_", nfo.second.instance_clock, nfo.second.instance_line, FF_Q) << ")," << endl;
    // reset
    out << '.' << ALG_RESET << '(' << prefixIdentifier("_", nfo.second.instance_reset, nfo.second.instance_line, FF_Q) << ")," << endl;
    // inputs
    for (const auto &is : nfo.second.algo->m_Inputs) {
      out << '.' << ALG_INPUT << '_' << is.name << '(';
      if (nfo.second.boundinputs.count(is.name) > 0) {
        // input is bound, directly map bound VIO
        out << prefixIdentifier("_", nfo.second.boundinputs.at(is.name), nfo.second.instance_line);
      } else {
        // input is not bound and assigned in logic, input is a flip-flop
        out << FF_D;
        out << nfo.second.instance_prefix << "_" << is.name;
      }
      out << ')' << ',' << endl;
    }
    // outputs
    for (const auto& os : nfo.second.algo->m_Outputs) {
      out << '.'
        << ALG_OUTPUT << '_' << os.name
        << '(' << WIRE << nfo.second.instance_prefix << '_' << os.name << ')';
      out << ',' << endl;
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
