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

#include <pybind11/pybind11.h>
#include <pybind11/stl.h>
namespace py = pybind11;

// ------------------------------------------------------------
// Implementations
// ------------------------------------------------------------

#include <filesystem>

#include "SiliceCompiler.h"
using namespace Silice;

// ------------------------------------------------------------

static std::string g_SiliceRootPath;

void setSiliceRootPath(std::string path)
{
  g_SiliceRootPath = std::filesystem::path(path).remove_filename().string();
  std::cerr << "########## SILICE ROOT PATH: " << g_SiliceRootPath << std::endl;
}

// ------------------------------------------------------------

class Instance
{
private:
  std::string m_ModuleName;
  std::string m_SourceFile;
public:
  Instance(std::string mname,std::string sfile)
    : m_ModuleName(mname), m_SourceFile(sfile)
  {

  }

  const std::string& moduleName() const { return m_ModuleName; }
  const std::string& sourceFile() const { return m_SourceFile; }
};

// ------------------------------------------------------------

class Unit
{
private:

  AutoPtr<SiliceCompiler> m_Compiler;
  AutoPtr<Blueprint>      m_Blueprint;
  std::string             m_Name;

public:

  Unit() {}

  Unit(std::string name, AutoPtr<Blueprint> bp, AutoPtr<SiliceCompiler> compiler)
    : m_Name(name), m_Blueprint(bp), m_Compiler(compiler) {}

  void splitExportParameter(
    std::tuple<std::string,std::string,std::string>& ex,
    std::vector<std::string>&                       _export_defs)
  {
    std::string name = std::get<0>(ex);
    std::transform(name.begin(), name.end(), name.begin(),
      [](unsigned char c) -> unsigned char { return std::toupper(c); });
    // split type
    t_type_nfo type_nfo;
    splitType(std::get<1>(ex), type_nfo);
    // add strings
    _export_defs.push_back(name+"_WIDTH=" + std::to_string(type_nfo.width));
    _export_defs.push_back(name+"_SIGNED=" + (type_nfo.base_type == Int ? "1" : "0" ));
    _export_defs.push_back(name+"_INIT=" + std::get<2>(ex));
  }

  Instance instantiate(const std::vector<std::tuple<std::string,std::string,std::string> >& export_params,std::string postfix)
  {
    if (m_Compiler.isNull()) {
      throw Fatal("invalid Unit");
    }
    // write to temp file
    std::string tmp = Utils::tempFileName() + ".v";
    std::ofstream f(tmp);
    // paramterized definitions
    std::vector<std::string> export_defs;
    for (auto ex : export_params) {
      splitExportParameter(ex,export_defs);
    }
    // verify we have all
    auto prmd = listParameterized();
    std::set<std::string> needed;
    needed.insert(prmd.begin(),prmd.end());
    std::set<std::string> given;
    for (auto ex : export_params) { given.insert(std::get<0>(ex)); }
    bool not_ok = false;
    for (auto n : needed) {
      if (given.count(n) == 0) {
        std::string msg = "unit needs definition for parameterized io '" + n + "'\n";
        std::cerr << Console::red << msg << Console::gray;
        not_ok = true;
      }
    }
    if (not_ok) {
      throw Fatal("unit needs additional parameterized io definitions.");
    }
    // write the output
    m_Compiler->write(m_Name,export_defs,postfix,f);
    // done
    f.close();
    // return instance
    return Instance("M_" + m_Name + (postfix.empty() ? "" : ("_" + postfix)), tmp);
  }

  Instance instantiate(const std::vector<std::tuple<std::string,std::string,std::string> >& export_params)
  {
    return instantiate(export_params,"");
  }

  Instance instantiate()
  {
    std::vector<std::tuple<std::string,std::string,std::string> > export_params;
    return instantiate(export_params,"");
  }

  std::vector<std::string> listInputs()
  {
    std::vector<std::string> names;
    for (auto i : m_Blueprint->inputs()) {
      names.push_back(i.name);
    }
    return names;
  }

  std::vector<std::string> listOutputs()
  {
    std::vector<std::string> names;
    for (auto o : m_Blueprint->outputs()) {
      names.push_back(o.name);
    }
    return names;
  }

  std::vector<std::string> listInOuts()
  {
    std::vector<std::string> names;
    for (auto i : m_Blueprint->inOuts()) {
      names.push_back(i.name);
    }
    return names;
  }

  std::vector<std::string> listParameterized()
  {
    std::vector<std::string> names;
    for (auto p : m_Blueprint->parameterized()) {
      names.push_back(p);
    }
    return names;
  }

  std::pair<bool,int> getVioType(std::string vio)
  {
    bool found = false;
    auto nfo = m_Blueprint->getVIODefinition(vio,found);
    if (!found) {
      std::cerr << "Cannot find vio " << vio << std::endl;
      return std::make_pair(false,0);
    } else {
      return std::make_pair(
        nfo.type_nfo.base_type == Int, // signed?
        nfo.type_nfo.width // width
        );
    }
  }
};

// ------------------------------------------------------------

class Design
{
private:

  AutoPtr<SiliceCompiler> m_Compiler;

  void parse(std::string filename,const std::vector<std::string>& defines)
  {
    try {
      std::string tmp_out = Utils::tempFileName();
      std::vector<std::string> export_params;
      m_Compiler = AutoPtr<SiliceCompiler>(new SiliceCompiler());
      std::vector<std::string> defs = defines;
      defs.push_back("HARDWARE=1");
      m_Compiler->parse(
        filename,
        tmp_out,
        std::filesystem::absolute(g_SiliceRootPath + "/frameworks/boards/bare/bare.v").string(),
        std::filesystem::absolute(g_SiliceRootPath + "/frameworks/").string(),
        defs
      );
    } catch (Fatal& err) {
      std::cerr << Console::red << "error: " << err.message() << Console::gray << "\n";
      throw;
    } catch (std::exception& err) {
      std::cerr << "error: " << err.what() << "\n";
      throw;
    }
  }

public:

  Design(const std::string& fname)
  {
    std::vector<std::string> defines;
    parse(fname,defines);
  }

  Design(const std::string& fname,const std::vector<std::string>& defines)
  {
    parse(fname,defines);
  }

  std::vector<std::string> listUnits()
  {
    std::vector<std::string> names;
    for (auto b : m_Compiler->getBlueprints()) {
      names.push_back(b.first);
    }
    return names;
  }

  Unit getUnit(std::string unit)
  {
    auto blueprints = m_Compiler->getBlueprints();
    auto B = blueprints.find(unit);
    if (B == blueprints.end()) { /// TODO: issue error
      std::cerr << "Cannot find unit " << unit << std::endl;
      return Unit();
    } else {
      return Unit(unit,B->second,m_Compiler);
    }
  }

  std::string unitCompiledName(std::string unit)
  {
    auto blueprints = m_Compiler->getBlueprints();
    auto B = blueprints.find(unit);
    if (B == blueprints.end()) {
      /// TODO: issue error
      std::cerr << "Cannot find unit " << unit << std::endl;
      return "";
    } else {
      return "M_" + B->first;
    }
  }

};

// ------------------------------------------------------------
// Python bindings
// ------------------------------------------------------------

PYBIND11_MODULE(_silice, m) {
    m.doc() = "Silice python plugin";
    m.def("setSiliceRootPath",&setSiliceRootPath);
    py::class_<Design>(m, "Design")
            .def(py::init<const std::string &,const std::vector<std::string>&>())
            .def(py::init<const std::string &>())
            .def("listUnits", &Design::listUnits)
            .def("getUnit", &Design::getUnit)
            ;
    py::class_<Unit>(m, "Unit")
//          .def(py::init<std::string,std::string>())
            .def("instantiate", static_cast<Instance (Unit::*)()>(&Unit::instantiate))
            .def("instantiate", static_cast<Instance (Unit::*)(const std::vector<std::tuple<std::string,std::string,std::string>>&)>(&Unit::instantiate))
            .def("instantiate", static_cast<Instance (Unit::*)(const std::vector<std::tuple<std::string,std::string,std::string>>&,std::string)>(&Unit::instantiate))
            .def("listInputs", &Unit::listInputs)
            .def("listOutputs", &Unit::listOutputs)
            .def("listInOuts", &Unit::listInOuts)
            .def("listParameterized", &Unit::listParameterized)
            .def("getVioType", &Unit::getVioType)
            ;
    py::class_<Instance>(m, "Instance")
//          .def(py::init<std::string,std::string>())
            .def("moduleName", &Instance::moduleName)
            .def("sourceFile", &Instance::sourceFile)
            ;
}

// ------------------------------------------------------------
