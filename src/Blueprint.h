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
#pragma once
// -------------------------------------------------
//                                ... hardcoding ...
// -------------------------------------------------

#include <string>

#include "siliceLexer.h"
#include "siliceParser.h"

#include "TypesAndConsts.h"

namespace Silice
{

  class Blueprint
  {
  private:

  public:

    /// \brief enum for variable access
    /// e_ReadWrite = e_ReadOnly | e_WriteOnly
    enum e_Access {
      e_NotAccessed = 0,
      e_ReadOnly = 1,
      e_WriteOnly = 2,
      e_ReadWrite = 3,
      e_WriteBinded = 4,
      e_ReadWriteBinded = 8,
      e_InternalFlipFlop = 16
    };

    /// \brief enum for variable type
    enum e_VarUsage {
      e_Undetermined = 0,
      e_NotUsed = 1,
      e_Const = 2,
      e_Temporary = 3,
      e_FlipFlop = 4,
      e_Bound = 5,
      e_Wire = 6
    };

    /// \brief base info about variables, inputs, outputs
    class t_var_nfo { // NOTE: if changed, remember to check var_nfo_copy
    public:
      std::string  name;
      t_type_nfo   type_nfo;
      std::vector<std::string> init_values;
      int          table_size; // 0: not a table, otherwise size
      bool         do_not_initialize = false;
      bool         init_at_startup = false;
      std::string  pipeline_prev_name; // if not empty, name of previous in pipeline trickling
      e_Access     access = e_NotAccessed;
      e_VarUsage   usage = e_Undetermined;
      std::string  attribs;
      antlr4::misc::Interval source_interval;
    };

    /// \brief typedef to distinguish vars from ios
    class t_inout_nfo : public t_var_nfo {
    public:
      bool nolatch = false;
    };

    /// \brief specialized info class for outputs
    class t_output_nfo : public t_var_nfo {
    public:
      bool combinational = false;
    };

    /// \brief information about instantiation (public for linter)
    typedef struct {
      std::string                                  instance_name;
      std::string                                  local_instance_name;
      std::unordered_map<std::string, std::string> parameters;
    } t_instantiation_context;

    /// \brief writes the blueprint as a Verilog module, recurses through instanced blueprints
    virtual void writeAsModule(std::ostream &out, const t_instantiation_context &ictx, bool first_pass) = 0;

  };

};

// -------------------------------------------------
