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
//                                ... hardcoding ...
// -------------------------------------------------

#include "TypesAndConsts.h"
#include <cctype>

using namespace std;
using namespace antlr4;
using namespace Silice;

// -------------------------------------------------

void Silice::splitType(std::string type, t_type_nfo& _type_nfo)
{
  std::regex  rx_type("([[:alpha:]]+)([[:digit:]]+)");
  std::smatch sm_type;
  bool ok = std::regex_search(type, sm_type, rx_type);
  sl_assert(ok);
  // type
  if (sm_type[1] == "int") { _type_nfo.base_type = Int; } else if (sm_type[1] == "uint") { _type_nfo.base_type = UInt; } else { sl_assert(false); }
  // width
  _type_nfo.width = atoi(sm_type[2].str().c_str());
}

// -------------------------------------------------

void Silice::splitConstant(std::string cst, int& _width, char& _base, std::string& _value, bool& _negative)
{
  std::regex  rx_type("(-?)([[:digit:]]+)([bdh])([[:digit:]a-fA-Fxz]+)");
  std::smatch sm_type;
  bool ok = std::regex_search(cst, sm_type, rx_type);
  sl_assert(ok);
  _width = atoi(sm_type[2].str().c_str());
  _base = sm_type[3].str()[0];
  _value = sm_type[4].str();
  _negative = !sm_type[1].str().empty();
}

// -------------------------------------------------

void Silice::constantTypeInfo(std::string cst, t_type_nfo& _nfo)
{
  int width; char base; std::string value; bool negative;
  splitConstant(cst, width, base, value, negative);
  _nfo.width = width;
  _nfo.base_type = UInt; // NOTE: constants are always written as unsigned Verilog constants
  int basis = -1;
  switch (base) {
  case 'b': basis = 2; break;
  case 'd': basis = 10; break;
  case 'h': basis = 16; break;
  default: throw Fatal("internal error [%s, %d]", __FILE__, __LINE__); break;
  }
}

// -------------------------------------------------
