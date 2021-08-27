/*

    Silice FPGA language and compiler
    Copyright 2019, (C) Sylvain Lefebvre and contributors 

    List contributors with: git shortlog -n -s -- <filename>

    GPLv3 license

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
  class Module
  {
  private:

    typedef struct {
      std::string name;
      bool        reg;
      int         first;
      int         second;
    } t_binding_point_nfo;

    std::string m_FileName;

    std::string m_Name;

    std::unordered_map<std::string, t_binding_point_nfo> m_Inputs;
    std::unordered_map<std::string, t_binding_point_nfo> m_Outputs;
    std::unordered_map<std::string, t_binding_point_nfo> m_InOuts;

    void gather(vmoduleParser::VmoduleContext *vmodule)
    {
      m_Name = vmodule->IDENTIFIER()->getText();
      vmoduleParser::InOutListContext *list = vmodule->inOutList();
      for (auto io : list->inOrOut()) {
        if (io->input()) {
          t_binding_point_nfo nfo;
          nfo.name = io->input()->IDENTIFIER()->getText();
          nfo.reg = (io->input()->mod()->REG() != nullptr);
          nfo.first = nfo.second = 0;
          if (io->input()->mod()->first != nullptr) {
            nfo.first = atoi(io->input()->mod()->first->getText().c_str());
            nfo.second = atoi(io->input()->mod()->second->getText().c_str());
          }
          m_Inputs[nfo.name] = nfo;
        } else if (io->output()) {
          t_binding_point_nfo nfo;
          nfo.name = io->output()->IDENTIFIER()->getText();
          nfo.reg = (io->output()->mod()->REG() != nullptr);
          nfo.first = nfo.second = 0;
          if (io->output()->mod()->first != nullptr) {
            nfo.first = atoi(io->output()->mod()->first->getText().c_str());
            nfo.second = atoi(io->output()->mod()->second->getText().c_str());
          }
          m_Outputs[nfo.name] = nfo;
        } else if (io->inout()) {
          t_binding_point_nfo nfo;
          nfo.name = io->inout()->IDENTIFIER()->getText();
          nfo.reg = (io->inout()->mod()->REG() != nullptr);
          nfo.first = nfo.second = 0;
          if (io->inout()->mod()->first != nullptr) {
            nfo.first = atoi(io->inout()->mod()->first->getText().c_str());
            nfo.second = atoi(io->inout()->mod()->second->getText().c_str());
          }
          m_InOuts[nfo.name] = nfo;
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

    std::string name() const { return m_Name; }

    void writeModule(std::ostream& out) const
    {
      if (!LibSL::System::File::exists(m_FileName.c_str())) {
        throw Fatal("cannot find imported module file '%s'", m_FileName.c_str());
      }
      out << std::endl;
      out << fileToString(m_FileName.c_str());
      out << std::endl;
    }

    const t_binding_point_nfo& output(std::string name) const
    {
      if (m_Outputs.find(name) == m_Outputs.end()) {
        throw Fatal("cannot find output '%s' in imported module '%s'", name.c_str(), m_FileName.c_str());
      }
      return m_Outputs.at(name);
    }

    const t_binding_point_nfo& input(std::string name) const
    {
      if (m_Inputs.find(name) == m_Inputs.end()) {
        throw Fatal("cannot find input '%s' in imported module '%s'", name.c_str(), m_FileName.c_str());
      }
      return m_Inputs.at(name);
    }

    const t_binding_point_nfo& inout(std::string name) const
    {
      if (m_InOuts.find(name) == m_InOuts.end()) {
        throw Fatal("cannot find inout '%s' in imported module '%s'", name.c_str(), m_FileName.c_str());
      }
      return m_InOuts.at(name);
    }

    const std::unordered_map<std::string, t_binding_point_nfo>& inputs()  const { return m_Inputs; }
    const std::unordered_map<std::string, t_binding_point_nfo>& outputs() const { return m_Outputs; }
    const std::unordered_map<std::string, t_binding_point_nfo>& inouts()  const { return m_InOuts; }

    static std::string fileToString(const char* file)
    {
      std::ifstream infile(file);
      if (!infile) {
        throw LibSL::Errors::Fatal("[loadFileIntoString] - file '%s' not found", file);
      }
      std::ostringstream strstream;
      while (infile) { // TODO: improve efficienty
        std::ifstream::int_type c = infile.get();
        if (c != (-1)) // EOF
          strstream << char(c);
        else
          break;
      }
      return strstream.str();
    }
  };

  // -------------------------------------------------

};
