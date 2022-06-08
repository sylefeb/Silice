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

#include "Blueprint.h"
#include "Utils.h"

// -------------------------------------------------

using namespace Silice;
using namespace Silice::Utils;

// -------------------------------------------------

// templated helper to search for vios definitions
template <typename T>
bool findVIO(std::string vio, std::unordered_map<std::string, int> names, std::vector<T> vars, Blueprint::t_var_nfo& _def)
{
  auto V = names.find(vio);
  if (V != names.end()) {
    _def = vars[V->second];
    return true;
  }
  return false;
}

// -------------------------------------------------

Blueprint::t_var_nfo Blueprint::getVIODefinition(std::string var, bool& _found) const
{
  t_var_nfo def;
  _found = true;
  if (findVIO(var, inputNames(),  inputs(),  def)) return def;
  if (findVIO(var, outputNames(), outputs(), def)) return def;
  if (findVIO(var, inOutNames(),  inOuts(),  def)) return def;
  _found = false;
  return def;
}
// -------------------------------------------------

std::tuple<t_type_nfo, int> Blueprint::determineVIOTypeWidthAndTableSize(std::string vname, const t_source_loc& srcloc) const
{
  t_type_nfo tn;
  tn.base_type = Int;
  tn.width = -1;
  int table_size = 0;
  if (isInput(vname)) {
    tn = input(vname).type_nfo;
    table_size = input(vname).table_size;
  } else if (isOutput(vname)) {
    tn = output(vname).type_nfo;
    table_size = output(vname).table_size;
  } else if (isInOut(vname)) {
    tn = inout(vname).type_nfo;
    table_size = inout(vname).table_size;
  } else {
    reportError(srcloc, "variable '%s' not yet declared", vname.c_str());
  }
  return std::make_tuple(tn, table_size);
}

// -------------------------------------------------

std::string Blueprint::resolveWidthOf(std::string vio, const t_instantiation_context &ictx, const t_source_loc& srcloc) const
{
  if (isInput(vio)) {
    auto tn = input(vio).type_nfo;
    return std::to_string(tn.width);
  } else if (isOutput(vio)) {
    auto tn = output(vio).type_nfo;
    return std::to_string(tn.width);
  } else if (isInOut(vio)) {
    auto tn = inout(vio).type_nfo;
    return std::to_string(tn.width);
  } else {
    reportError(srcloc, "variable '%s' not yet declared", vio.c_str());
    return "";
  }
}

// -------------------------------------------------

std::string Blueprint::typeString(e_Type type) const
{
  if (type == Int) {
    return "signed";
  }
  return "";
}

// -------------------------------------------------

std::string Blueprint::varBitRange(const t_var_nfo& v, const t_instantiation_context &ictx) const
{
  if (v.type_nfo.base_type == Parameterized) {
    bool ok = false;
    t_var_nfo base = getVIODefinition(v.type_nfo.same_as.empty() ? v.name : v.type_nfo.same_as, ok);
    if (!ok) {
      reportError(v.srcloc, "cannot find definition of '%s' ('%s')", v.type_nfo.same_as.empty() ? v.name.c_str() : v.type_nfo.same_as.c_str(), v.name.c_str());
    }
    std::string str;
    if (base.type_nfo.base_type == Parameterized) {
      str = base.name;
      std::transform(str.begin(), str.end(), str.begin(),
        [](unsigned char c) -> unsigned char { return std::toupper(c); });
      str = str + "_WIDTH";
      if (ictx.parameters.count(str) == 0) {
        reportError(v.srcloc, "cannot find value of '%s' during instantiation of unit '%s'", str.c_str(), name().c_str());
      }
      str = ictx.parameters.at(str) + "-1"; // NOTE: this should always be a legal value, and never a reference
    } else {
      str = std::to_string(base.type_nfo.width - 1);
    }
    return "[" + str + ":0]";
  } else {
    return "[" + std::to_string(v.type_nfo.width - 1) + ":0]";
  }
}

// -------------------------------------------------

std::string Blueprint::varBitWidth(const t_var_nfo &v, const t_instantiation_context &ictx) const
{
  if (v.type_nfo.base_type == Parameterized) {
    bool ok = false;
    t_var_nfo base = getVIODefinition(v.type_nfo.same_as.empty() ? v.name : v.type_nfo.same_as, ok);
    if (!ok) {
      reportError(v.srcloc, "cannot find definition of '%s' ('%s')", v.type_nfo.same_as.empty() ? v.name.c_str() : v.type_nfo.same_as.c_str(), v.name.c_str());
    }
    std::string str;
    if (base.type_nfo.base_type == Parameterized) {
      str = base.name;
      std::transform(str.begin(), str.end(), str.begin(),
        [](unsigned char c) -> unsigned char { return std::toupper(c); });
      str = str + "_WIDTH";
      if (ictx.parameters.count(str) == 0) {
        return str;
      } else {
        str = ictx.parameters.at(str); // NOTE: this should always be a legal value, and never a reference
      }
    } else {
      str = std::to_string(base.type_nfo.width);
    }
    return str;
  } else {
    return std::to_string(v.type_nfo.width);
  }
}

// -------------------------------------------------

std::string Blueprint::varInitValue(const t_var_nfo &v, const t_instantiation_context &ictx) const
{
  sl_assert(v.table_size == 0);
  if (v.type_nfo.base_type == Parameterized) {
    bool ok = false;
    t_var_nfo base = getVIODefinition(v.type_nfo.same_as.empty() ? v.name : v.type_nfo.same_as, ok);
    sl_assert(ok);
    std::string str;
    if (base.type_nfo.base_type == Parameterized) {
      str = base.name;
      std::transform(str.begin(), str.end(), str.begin(),
        [](unsigned char c) -> unsigned char { return std::toupper(c); });
      str = str + "_INIT";
      if (ictx.parameters.count(str) == 0) {
        reportError(v.srcloc, "cannot find value of '%s' during instantiation of unit '%s'", str.c_str(), name().c_str());
      }
      str = ictx.parameters.at(str); // NOTE: this should always be a legal value, and never a reference
    } else {
      if (base.init_values.empty()) {
        str = "0";
      } else {
        str = base.init_values[0];
      }
    }
    return str;
  } else {
    sl_assert(!v.init_values.empty() || v.do_not_initialize);
    if (v.init_values.empty()) {
      return "";
    } else {
      return v.init_values[0];
    }
  }
}

// -------------------------------------------------

e_Type Blueprint::varType(const t_var_nfo &v, const t_instantiation_context &ictx) const
{
  if (v.type_nfo.base_type == Parameterized) {
    bool ok = false;
    t_var_nfo base = getVIODefinition(v.type_nfo.same_as.empty() ? v.name : v.type_nfo.same_as, ok);
    if (!ok) {
      reportError(v.srcloc, "cannot determine type of '%s' during instantiation of unit '%s', input or output not bound?", v.name.c_str(), name().c_str());
    }
    std::string str;
    if (base.type_nfo.base_type == Parameterized) {
      str = base.name;
      std::transform(str.begin(), str.end(), str.begin(),
        [](unsigned char c) -> unsigned char { return std::toupper(c); });
      str = str + "_SIGNED";
      if (ictx.parameters.count(str) == 0) {
        reportError(v.srcloc, "cannot find value of '%s' during instantiation of unit '%s'", str.c_str(), name().c_str());
      }
      str = ictx.parameters.at(str); // NOTE: this should always be a legal value, and never a reference
      return (str == "signed") ? Int : UInt;
    } else {
      return base.type_nfo.base_type;
    }
  } else {
    return v.type_nfo.base_type;
  }
}

// -------------------------------------------------
