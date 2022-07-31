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
#include "Utils.h"

namespace Silice
{

  class SiliceCompiler;

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
      int          table_size        = 0; // 0: not a table, otherwise size
      bool         do_not_initialize = false;
      bool         init_at_startup   = false;
      std::string  pipeline_prev_name; // if not empty, name of previous in pipeline trickling
      e_Access     access            = e_NotAccessed;
      e_VarUsage   usage             = e_Undetermined;
      std::string  attribs;
      Utils::t_source_loc srcloc;
    };

    /// \brief typedef to distinguish vars from ios
    class t_inout_nfo : public t_var_nfo {
    public:
    };

    /// \brief specialized info class for outputs
    class t_output_nfo : public t_var_nfo {
    public:
      bool combinational = false;
      bool combinational_nocheck = false; // when true, this is ignored in combinational cycle checks (if combinational == true)
    };

    /// \brief information about instantiation
    typedef struct {
      std::string                                  instance_name;
      std::string                                  local_instance_name;
      std::unordered_map<std::string, std::string> parameters;
    } t_instantiation_context;

    /// \brief returns the blueprint name
    virtual std::string name() const = 0;
    /// \brief sets as a top module in the output stream
    virtual void setAsTopMost() { }
    /// \brief writes the blueprint as a Verilog module
    virtual void writeAsModule(SiliceCompiler *compiler, std::ostream& out, const t_instantiation_context& ictx, bool first_pass) = 0;
    /// \brief returns true if the blueprint requires a reset
    virtual bool requiresReset() const = 0;
    /// \brief returns true if the blueprint requires a clock
    virtual bool requiresClock() const = 0;
    /// \brief returns true if the blueprint is not callable with the (.) <- . <- (.) syntax
    virtual bool isNotCallable() const = 0;
    /// \brief inputs
    virtual const std::vector<t_inout_nfo>&   inputs() const = 0;
    /// \brief outputs
    virtual const std::vector<t_output_nfo >& outputs() const = 0;
    /// \brief inouts
    virtual const std::vector<t_inout_nfo >&  inOuts() const = 0;
    /// \brief parameterized vars
    virtual const std::vector<std::string >&  parameterized() const = 0;
    /// \brief all input names, map contains index in m_Inputs
    virtual const std::unordered_map<std::string, int >& inputNames()  const = 0;
    /// \brief all output names, map contains index in m_Outputs
    virtual const std::unordered_map<std::string, int >& outputNames() const = 0;
    /// \brief all inout names, map contains index in m_InOuts
    virtual const std::unordered_map<std::string, int >& inOutNames()  const = 0;
    /// \brief returns a VIO definition
    virtual t_var_nfo getVIODefinition(std::string var, bool &_found) const;
    /// \brief determines vio bit width and (if applicable) table size
    virtual std::tuple<t_type_nfo, int> determineVIOTypeWidthAndTableSize(std::string vname, const Utils::t_source_loc& srcloc) const;
    /// \brief determines vio bit width
    virtual std::string resolveWidthOf(std::string vio, const t_instantiation_context& ictx, const Utils::t_source_loc& srcloc) const;
    /// \brief returns the name of the module
    virtual std::string moduleName(std::string blueprint_name,std::string instance_name) const = 0;
    /// \brief returns the name of an input port from its internal name
    virtual std::string inputPortName(std::string name)  const { return name; }
    /// \brief returns the name of an output port from its internal name
    virtual std::string outputPortName(std::string name) const { return name; }
    /// \brief returns the name of an inout port from its internal name
    virtual std::string inoutPortName(std::string name)  const { return name; }
    /// \brief returns variable bit range for verilog declaration
    virtual std::string varBitRange(const t_var_nfo& v, const t_instantiation_context &ictx) const;
    /// \brief returns a variable bit width for verilog use
    virtual std::string varBitWidth(const t_var_nfo &v, const t_instantiation_context &ictx) const;
    /// \brief returns a variable init value for verilog use (non-tables only)
    virtual std::string varInitValue(const t_var_nfo &v, const t_instantiation_context &ictx) const;
    /// \brief returns the base type of a variable
    virtual e_Type      varType(const t_var_nfo& v, const t_instantiation_context &ictx) const;
    /// \brief returns a type dependent string for resource declaration
    virtual std::string typeString(e_Type type) const;

    /// \brief returns true of the 'combinational' boolean is properly setup for outputs
    virtual bool hasOutputCombinationalInfo() const = 0;

    /// \brief utility accessor to output by name
    const t_output_nfo& output(std::string name) const
    {
      auto F = outputNames().find(name);
      if (F == outputNames().end()) {
        throw Fatal("cannot find output '%s'", name.c_str());
      }
      return outputs().at(F->second);
    }
    /// \brief utility accessor to input by name
    const t_inout_nfo& input(std::string name) const
    {
      auto F = inputNames().find(name);
      if (F == inputNames().end()) {
        throw Fatal("cannot find input '%s'", name.c_str());
      }
      return inputs().at(F->second);
    }
    /// \brief utility accessor to inout by name
    const t_inout_nfo& inout(std::string name) const
    {
      auto F = inOutNames().find(name);
      if (F == inOutNames().end()) {
        throw Fatal("cannot find inout '%s'", name.c_str());
      }
      return inOuts().at(F->second);
    }
    /// \brief returns true if var is an input
    bool isInput(std::string var) const
    {
      return (inputNames().find(var) != inputNames().end());
    }
    /// \brief returns true if var is an output
    bool isOutput(std::string var) const
    {
      return (outputNames().find(var) != outputNames().end());
    }
    /// \brief returns true if var is an inOut
    bool isInOut(std::string var) const
    {
      return (inOutNames().find(var) != inOutNames().end());
    }
    /// \brief returns true if var is an input or an output
    bool isInputOrOutput(std::string var) const
    {
      return isInput(var) || isOutput(var);
    }

  };

};

// -------------------------------------------------
