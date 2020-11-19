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
  m_KeyValues["bram_template"]                = "bram_generic.v.in"; 
  m_KeyValues["bram_wenable_type"]            = "uint"; // uint | int | data
  m_KeyValues["bram_wenable_width"]           = "1";    // 1 | data
  
  m_KeyValues["brom_template"]                = "brom_generic.v.in";
  
  m_KeyValues["dualport_bram_template"]       = "dualport_bram_generic.v.in";
  m_KeyValues["dualport_bram_wenable0_type"]  = "uint"; // uint | int | data
  m_KeyValues["dualport_bram_wenable0_width"] = "1"; // 1 | data
  m_KeyValues["dualport_bram_wenable1_type"]  = "uint"; // uint | int | data
  m_KeyValues["dualport_bram_wenable1_width"] = "1"; // 1 | data

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
