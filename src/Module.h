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

#include <LibSL/LibSL.h>

#include "path.h"

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

  std::map<std::string, t_binding_point_nfo> m_Inputs;
  std::map<std::string, t_binding_point_nfo> m_Outputs;
  std::map<std::string, t_binding_point_nfo> m_InOuts;

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
    if (!LibSL::System::File::exists(fname.c_str())) {
      throw std::runtime_error("cannot find module file");
    }
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
      throw Fatal("cannot find imported module file '%s'",m_FileName.c_str());
    }
    out << std::endl;
    out << loadFileIntoString(m_FileName.c_str());
    out << std::endl;
  }

  const t_binding_point_nfo& output(std::string name) const
  {
    if (m_Outputs.find(name) == m_Outputs.end()) {
      throw Fatal("cannot find output in imported module '%s'",m_FileName.c_str());
    }
    return m_Outputs.at(name);
  }

  const std::map<std::string, t_binding_point_nfo>& inputs()  const { return m_Inputs;  }
  const std::map<std::string, t_binding_point_nfo>& outputs() const { return m_Outputs; }
  const std::map<std::string, t_binding_point_nfo>& inouts()  const { return m_InOuts;  }
};

// -------------------------------------------------
