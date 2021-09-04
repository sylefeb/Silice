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
// -------------------------------------------------

#include "VerilogTemplate.h"
#include "Module.h"

#include <LibSL/LibSL.h>
#include <regex>

using namespace std;
using namespace Silice;

// -------------------------------------------------

void VerilogTemplate::load(std::string fname, 
       const std::unordered_map<std::string,std::string>& keyValues)
{
  if (!LibSL::System::File::exists(fname.c_str())) {
    throw Fatal("cannot find template file '%s'",fname.c_str());
  }
  // load in string
  string code_in = Module::fileToString(fname.c_str());
  // apply variables
  for (auto kv : keyValues) {
    std::regex rexp("%" + kv.first + "%");
    code_in = std::regex_replace(code_in,rexp,kv.second);
  }
  m_Code = code_in;
}

// -------------------------------------------------
