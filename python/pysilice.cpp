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
namespace py = pybind11;

// ------------------------------------------------------------
// Python bindings
// ------------------------------------------------------------

std::string compile(std::string source);

PYBIND11_MODULE(_silice, m) {
    m.doc() = "Silice python plugin";
    m.def("compile", &compile, "Compile a source file to Verilog and returns the code.");
}

// ------------------------------------------------------------
// Implementations
// ------------------------------------------------------------

#include <filesystem>

#include "SiliceCompiler.h"
using namespace Silice;

std::string compile(std::string sourceFile)
{
  try {
    SiliceCompiler compiler;
    std::string tmp_out = Utils::tempFileName();
    std::vector<std::string> defines,export_params;
    defines.push_back("NUM_LEDS=8");
    compiler.run(
      sourceFile,
      tmp_out,
      std::filesystem::absolute("../frameworks/boards/bare/bare.v").string(),
      std::filesystem::absolute("../frameworks/").string(),
      defines,
      "",
      export_params
    );
    if (!LibSL::System::File::exists(tmp_out.c_str())) {
      return "";
    } else {
      return Utils::fileToString(tmp_out.c_str());
    }
  } catch (Fatal& err) {
    std::cerr << Console::red << "error: " << err.message() << Console::gray << "\n";
    return "";
  } catch (std::exception& err) {
    std::cerr << "error: " << err.what() << "\n";
    return "";
  }
}

// ------------------------------------------------------------
