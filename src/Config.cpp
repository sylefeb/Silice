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

#include "Config.h"
#include <LibSL/LibSL.h>
#include <iomanip>

using namespace std;

// -------------------------------------------------

Config *Config::s_UniqueInstance = nullptr;

Config *Config::getUniqueInstance()
{
  if (s_UniqueInstance == nullptr) {
    s_UniqueInstance = new Config();
  }
  return s_UniqueInstance;
}
  
// -------------------------------------------------

Config::Config()
{  
  // initialize with defaults
  m_KeyValues["bram_supported"]               = "yes";
  m_KeyValues["bram_template"]                = "bram_generic.v.in"; 
  m_KeyValues["bram_wenable_type"]            = "uint"; // uint | int | data
  m_KeyValues["bram_wenable_width"]           = "1";    // 1 | data
  
  m_KeyValues["brom_supported"]               = "yes";
  m_KeyValues["brom_template"]                = "brom_generic.v.in";
  
  m_KeyValues["dualport_bram_supported"]      = "yes";
  m_KeyValues["dualport_bram_template"]       = "dualport_bram_generic.v.in";
  m_KeyValues["dualport_bram_wenable0_type"]  = "uint"; // uint | int | data
  m_KeyValues["dualport_bram_wenable0_width"] = "1"; // 1 | data
  m_KeyValues["dualport_bram_wenable1_type"]  = "uint"; // uint | int | data
  m_KeyValues["dualport_bram_wenable1_width"] = "1"; // 1 | data

  m_KeyValues["simple_dualport_bram_supported"]      = "yes";
  m_KeyValues["simple_dualport_bram_template"]       = "simple_dualport_bram_generic.v.in";
  m_KeyValues["simple_dualport_bram_wenable1_type"]  = "uint"; // uint | int | data
  m_KeyValues["simple_dualport_bram_wenable1_width"] = "1"; // 1 | data

  // internal options
  m_KeyValues["output_fsm_graph"]             = "1";
}

// -------------------------------------------------

void Config::print()
{
  for (auto kv : m_KeyValues) {
    cerr << Console::white  << setw(30) << kv.first << " = ";
    cerr << Console::yellow << setw(30) << kv.second << "\n";
  }
  cerr << Console::gray;
}

// -------------------------------------------------

const std::string nxl = "\n"; // end of line

// -------------------------------------------------
