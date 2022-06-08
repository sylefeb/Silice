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
//                                ... hardcoding ...
// -------------------------------------------------

#include "vmoduleLexer.h"
#include "vmoduleParser.h"

#include "Blueprint.h"
#include "Utils.h"

#include <string>
#include <iostream>
#include <fstream>
#include <regex>
#include <queue>
#include <unordered_map>

#include <LibSL/LibSL.h>

namespace Silice
{

  // -------------------------------------------------

  /// \brief class to store, parse and compile a module imported from Verilog
  class Module : public Blueprint
  {
  private:

    /// \brief module filename
    std::string m_FileName;
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

    /// \brief gather module information from parsed grammar
    void gather(vmoduleParser::VmoduleContext *vmodule)
    {
      m_Name = vmodule->IDENTIFIER()->getText();
      vmoduleParser::InOutListContext *list = vmodule->inOutList();
      for (auto io : list->inOrOut()) {
        if (io->input()) {
          t_inout_nfo nfo;
          nfo.name = io->input()->IDENTIFIER()->getText();
          nfo.do_not_initialize = true;
          nfo.type_nfo.base_type = UInt; // TODO signed?
          if (io->input()->mod()->first != nullptr) {
            int f = atoi(io->input()->mod()->first->getText().c_str());
            int s = atoi(io->input()->mod()->second->getText().c_str());
            nfo.type_nfo.width = f - s + 1;
          } else {
            nfo.type_nfo.width = 1;
          }
          m_Inputs.emplace_back(nfo);
          m_InputNames.insert(make_pair(nfo.name, (int)m_Inputs.size() - 1));
        } else if (io->output()) {
          t_output_nfo nfo;
          nfo.name = io->output()->IDENTIFIER()->getText();
          nfo.do_not_initialize = true;
          nfo.type_nfo.base_type = UInt; // TODO signed?
          if (io->output()->mod()->first != nullptr) {
            int f = atoi(io->output()->mod()->first->getText().c_str());
            int s = atoi(io->output()->mod()->second->getText().c_str());
            nfo.type_nfo.width = f - s + 1;
          } else {
            nfo.type_nfo.width = 1;
          }
          m_Outputs.emplace_back(nfo);
          m_OutputNames.insert(make_pair(nfo.name, (int)m_Outputs.size() - 1));
        } else if (io->inout()) {
          t_inout_nfo nfo;
          nfo.name = io->inout()->IDENTIFIER()->getText();
          nfo.do_not_initialize = true;
          nfo.type_nfo.base_type = UInt; // TODO signed?
          if (io->inout()->mod()->first != nullptr) {
            int f = atoi(io->inout()->mod()->first->getText().c_str());
            int s = atoi(io->inout()->mod()->second->getText().c_str());
            nfo.type_nfo.width = f - s + 1;
          } else {
            nfo.type_nfo.width = 1;
          }
          m_InOuts.emplace_back(nfo);
          m_InOutNames.insert(make_pair(nfo.name, (int)m_InOuts.size() - 1));
        } else {
          sl_assert(false);
        }
      }
    }

  public:

    /// \brief constructor
    Module(std::string fname) : m_FileName(fname)
    {
      std::cerr << "importing " << fname << '.' << std::endl;
      std::ifstream             file(fname);

      antlr4::ANTLRInputStream  input(file);
      vmoduleLexer              lexer(&input);
      antlr4::CommonTokenStream tokens(&lexer);
      vmoduleParser             parser(&tokens);

      gather(parser.vmodule());
    }

    void writeModule(std::ostream& out) const
    {
      if (!LibSL::System::File::exists(m_FileName.c_str())) {
        throw Fatal("cannot find imported module file '%s'", m_FileName.c_str());
      }
      out << std::endl;
      out << Utils::fileToString(m_FileName.c_str());
      out << std::endl;
    }

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
    /// \brief returns true if the algorithm is not callable
    bool isNotCallable() const override { return true; }
    /// \brief returns true if the blueprint requires a reset
    bool requiresReset() const override { return false; } // has to be manually provided from caller
    /// \brief returns true if the blueprint requires a clock
    bool requiresClock() const override { return false; } // has to be manually provided from caller
    /// \brief returns the name of the module
    std::string moduleName(std::string blueprint_name, std::string instance_name) const override { sl_assert(blueprint_name == m_Name);  return blueprint_name; }
    /// \brief returns true of the 'combinational' boolean is properly setup for outputs
    bool hasOutputCombinationalInfo() const override { return false; }

};

  // -------------------------------------------------

};
