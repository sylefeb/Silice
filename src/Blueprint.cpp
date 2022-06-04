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
