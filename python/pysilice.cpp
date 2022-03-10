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

class SiliceFile
{
private:
  SiliceCompiler compiler;

  void parse(const std::vector<std::string>& defines)
  {
    try {
      std::string tmp_out = Utils::tempFileName();
      std::vector<std::string> export_params;
      compiler.parse(
        filename,
        tmp_out,
        std::filesystem::absolute("../frameworks/boards/bare/bare.v").string(),
        std::filesystem::absolute("../frameworks/").string(),
        defines
      );
    } catch (Fatal& err) {
      std::cerr << Console::red << "error: " << err.message() << Console::gray << "\n";
    } catch (std::exception& err) {
      std::cerr << "error: " << err.what() << "\n";
    }
  }

public:

  SiliceFile(const std::string& fname,const std::vector<std::string>& defines) : filename(fname)
  {
    parse(defines);
  }

  std::string filename;

  std::vector<std::string> listUnits()
  {
    std::vector<std::string> names;
    for (auto b : compiler.getBlueprints()) {
      names.push_back(b.first);
    }
    return names;
  }

  std::vector<std::string> listUnitInputs(const std::string& name)
  {
    auto blueprints = compiler.getBlueprints();
    auto B = blueprints.find(name);
    if (B == blueprints.end()) {
      /// TODO: issue error
      std::cerr << "Cannot find unit " << name << std::endl;
      return std::vector<std::string>();
    } else {
      std::vector<std::string> names;
      for (auto i : B->second->inputs()) {
        names.push_back(i.name);
      }
      return names;
    }
  }

  std::vector<std::string> listUnitOutputs(const std::string& name)
  {
    auto blueprints = compiler.getBlueprints();
    auto B = blueprints.find(name);
    if (B == blueprints.end()) {
      /// TODO: issue error
      std::cerr << "Cannot find unit " << name << std::endl;
      return std::vector<std::string>();
    } else {
      std::vector<std::string> names;
      for (auto o : B->second->outputs()) {
        names.push_back(o.name);
      }
      return names;
    }
  }

  std::vector<std::string> listUnitInOuts(const std::string& name)
  {
    auto blueprints = compiler.getBlueprints();
    auto B = blueprints.find(name);
    if (B == blueprints.end()) {
      /// TODO: issue error
      std::cerr << "Cannot find unit " << name << std::endl;
      return std::vector<std::string>();
    } else {
      std::vector<std::string> names;
      for (auto i : B->second->inOuts()) {
        names.push_back(i.name);
      }
      return names;
    }
  }

  std::pair<bool,int> vioType(std::string unit,std::string vio)
  {
    auto blueprints = compiler.getBlueprints();
    auto B = blueprints.find(unit);
    if (B == blueprints.end()) {
      /// TODO: issue error
      std::cerr << "Cannot find unit " << unit << std::endl;
      return std::make_pair(false,0);
    } else {
      bool found = false;
      auto nfo = B->second->getVIODefinition(vio,found);
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
  }

};

// ------------------------------------------------------------
// Python bindings
// ------------------------------------------------------------

PYBIND11_MODULE(_silice, m) {
    m.doc() = "Silice python plugin";
    py::class_<SiliceFile>(m, "SiliceFile")
            .def(py::init<const std::string &,const std::vector<std::string>&>())
            .def("listUnits", &SiliceFile::listUnits)
            .def("listUnitInputs", &SiliceFile::listUnitInputs)
            .def("listUnitOutputs", &SiliceFile::listUnitOutputs)
            .def("listUnitInOuts", &SiliceFile::listUnitInOuts)
            .def("vioType", &SiliceFile::vioType)
            ;
}

// ------------------------------------------------------------
