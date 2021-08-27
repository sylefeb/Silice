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

#include "siliceLexer.h"
#include "siliceParser.h"

#include <string>
#include <iostream>
#include <fstream>
#include <regex>
#include <queue>
#include <unordered_set>
#include <unordered_map>
#include <numeric>

#include <LibSL/LibSL.h>

// -------------------------------------------------

namespace Silice
{

  /// \brief base types
  enum e_Type { Int, UInt, Parameterized };

  /// \brief info about a type
  class t_type_nfo {
  public:
    e_Type      base_type = UInt; // base type
    int         width     = 0;    // bit width
    std::string same_as;          // reference to a VIO which is parameterizing this type
    t_type_nfo(e_Type t,int w) : base_type(t), width(w) {}
    t_type_nfo() {}
  };

  /// \brief splits a type between base type and width
  void splitType(std::string type, t_type_nfo& _type_nfo);
  /// \brief splits a constant between width, base and value
  void splitConstant(std::string cst, int& _width, char& _base, std::string& _value, bool& _negative);
  /// \brief fills the type info of a constant
  void constantTypeInfo(std::string cst, t_type_nfo& _nfo);

};

// -------------------------------------------------
