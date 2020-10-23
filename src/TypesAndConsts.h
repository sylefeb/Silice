/*

    Silice FPGA language and compiler
    (c) Sylvain Lefebvre - @sylefeb

This work and all associated files are under the

     GNU AFFERO GENERAL PUBLIC LICENSE
        Version 3, 19 November 2007

With the additional clause that the copyright notice
above, identitfying the author and original copyright
holder must remain included in all distributions.

(header_1_0)
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
