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
#pragma once
// -------------------------------------------------

#include "siliceLexer.h"
#include "siliceParser.h"
#include "Blueprint.h"
#include "Utils.h"
#include "Algorithm.h"

namespace Silice
{

  class RISCVSynthesizer : public Blueprint
  {
  private:

    /// \brief module name
    std::string m_Name;
    /// \brief inputs
    std::vector< t_inout_nfo  > m_Inputs;
    /// \brief outputs
    std::vector< t_output_nfo > m_Outputs;
    /// \brief inouts
    std::vector< t_inout_nfo >  m_InOuts;
    /// \brief parameterized IO (always empty)
    std::vector< std::string >  m_Parameterized;
    /// \brief all input names, map contains index in m_Inputs
    std::unordered_map<std::string, int > m_InputNames;
    /// \brief all output names, map contains index in m_Outputs
    std::unordered_map<std::string, int > m_OutputNames;
    /// \brief all inout names, map contains index in m_InOuts
    std::unordered_map<std::string, int > m_InOutNames;

    /// \brief extracts C code
    std::string cblockToString(siliceParser::RiscvContext *riscv,siliceParser::CblockContext *cblock) const;
    /// \brief generates the C header for compilation
    std::string generateCHeader(siliceParser::RiscvContext *riscv) const;
    /// \brief generates the Silice codde for compilation
    std::string generateSiliceCode(siliceParser::RiscvContext *riscv) const;
    /// \brief returns the user-given memory size
    int         memorySize(siliceParser::RiscvContext *riscv) const;
    /// \brief returns the user-given stack size (if any, 0 otherwise)
    int         stackSize(siliceParser::RiscvContext *riscv) const;
    /// \brief returns the user-given core name (if any, default core selection otherwise)
    std::string coreName(siliceParser::RiscvContext *riscv) const;
    /// \brief returns the user-given architecture variant (defaults to rv32i otherwise)
    std::string archName(siliceParser::RiscvContext *riscv) const;
    /// \brief returns user-defines from modifiers
    std::string defines(siliceParser::RiscvContext *riscv) const;

    /// \brief gather module information from parsed grammar
    void        gather(siliceParser::RiscvContext *riscv);
    /// \brief gather information about type in declaration
    void        gatherTypeNfo(siliceParser::TypeContext *type, t_type_nfo &_nfo) const;

    /// \brief returns true if output is an access trigger (to an input or output)
    bool        isAccessTrigger(siliceParser::OutputContext *output,std::string& _accessed) const;

  public:

    RISCVSynthesizer(siliceParser::RiscvContext *riscv);

    /// \brief writes the compiled code into out
    void writeCompiled(std::ostream& out) { out << Utils::fileToString((m_Name + ".v").c_str()); }

    /// === implements Blueprint

    /// \brief returns the blueprint name
    std::string name() const override { return m_Name; }
    /// \brief writes the algorithm as a Verilog module, recurses through instanced blueprints
    void writeAsModule(SiliceCompiler *compiler, std::ostream& out, const t_instantiation_context& ictx, bool first_pass) { }
    /// \brief inputs
    const std::vector<t_inout_nfo>& inputs()         const override { return m_Inputs; }
    /// \brief outputs
    const std::vector<t_output_nfo >& outputs()      const override { return m_Outputs; }
    /// \brief inouts
    const std::vector<t_inout_nfo >& inOuts()        const override { return m_InOuts; }
    /// \brief parameterized vars
    const std::vector<std::string >& parameterized() const override { return m_Parameterized; }
    /// \brief all input names, map contains index in m_Inputs
    const std::unordered_map<std::string, int >& inputNames()  const override { return m_InputNames; }
    /// \brief all output names, map contains index in m_Outputs
    const std::unordered_map<std::string, int >& outputNames() const override { return m_OutputNames; }
    /// \brief all inout names, map contains index in m_InOuts
    const std::unordered_map<std::string, int >& inOutNames()  const override { return m_InOutNames; }
    /// \brief returns the name of an input port from its internal name
    std::string inputPortName(std::string name)  const override { return std::string(ALG_INPUT) + '_' + name; }
    /// \brief returns the name of an output port from its internal name
    std::string outputPortName(std::string name) const override { return std::string(ALG_OUTPUT) + '_' + name; }
    /// \brief returns the name of an inout port from its internal name
    std::string inoutPortName(std::string name)  const override { return std::string(ALG_INOUT) + '_' + name; }
    /// \brief returns true if the algorithm is not callable
    bool isNotCallable() const override { return true; }
    /// \brief returns true if the blueprint requires a reset
    bool requiresReset() const override { return true; }
    /// \brief returns true if the blueprint requires a clock
    bool requiresClock() const override { return true; }
    /// \brief returns the name of the module
    std::string moduleName(std::string blueprint_name, std::string instance_name) const override { return "M_" + blueprint_name; }
    /// \brief returns true of the 'combinational' boolean is properly setup for outputs
    bool hasOutputCombinationalInfo() const override { return true; }

  };

};

// -------------------------------------------------
