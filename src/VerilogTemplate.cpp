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
