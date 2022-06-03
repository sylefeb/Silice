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

/*

/// TODO on new pre-processor approach

- clock/reset in Algorithm::instantiateBlueprints
- RISCVSynthesizer
- formal unit tests


*/

// -------------------------------------------------
//                                ... hardcoding ...
// -------------------------------------------------

#include "Algorithm.h"
#include "Module.h"
#include "LuaPreProcessor.h"
#include "ParsingContext.h"
#include "ParsingErrors.h"

// -------------------------------------------------

#include <string>
#include <iostream>
#include <fstream>
#include <regex>
#include <queue>
#include <cstdio>

#include <LibSL/LibSL.h>

namespace Silice {

  // -------------------------------------------------

  class SiliceCompiler
  {
  private:

    std::unordered_map<std::string, AutoPtr<Blueprint> >               m_Blueprints;
    std::vector<std::string>                                           m_BlueprintsInDeclOrder;
    std::unordered_map<std::string, siliceParser::SubroutineContext* > m_Subroutines;
    std::unordered_map<std::string, siliceParser::CircuitryContext* >  m_Circuitries;
    std::unordered_map<std::string, siliceParser::GroupContext* >      m_Groups;
    std::unordered_map<std::string, siliceParser::IntrfaceContext * > m_Interfaces;
    std::unordered_map<std::string, siliceParser::BitfieldContext* >   m_BitFields;
    std::unordered_set<std::string>                                    m_Appends;
    std::vector<std::string>                                           m_AppendsInDeclOrder;

    const std::vector<std::string> c_DefaultLibraries = { "memory_ports.si" };

    /// \brief finds a file by checking throughout paths known to be used by the source code
    std::string findFile(std::string fname) const;
    /// \brief gathers all body constructs from the source code file
    void gatherBody(antlr4::tree::ParseTree* tree);
    /// \brief prepare the hardware fraemwork before compilation
    void prepareFramework(std::string fframework, std::string& _lpp, std::string& _verilog);
    /// \brief gather a unit from the parsed tree
    AutoPtr<Blueprint> gatherUnit(antlr4::tree::ParseTree* tree);

    /// \brief body parsing context
    AutoPtr<ParsingContext> m_BodyContext;

    /// \brief begin parsing
    void beginParsing(
      std::string fsource,
      std::string fresult,
      std::string fframework,
      std::string frameworks_dir,
      const std::vector<std::string>& defines);

    /// \brief end parsing
    void endParsing();

  public:

    /// \brief runs the compiler (calls parse and write)
    void run(
      std::string fsource,
      std::string fresult,
      std::string fframework,
      std::string frameworks_dir,
      const std::vector<std::string>& defines,
      std::string to_export,
      const std::vector<std::string>& export_params);

    /// \brief writes the design body in the output stream
    void writeBody(std::ostream& _out);

    /// \brief writes a unit in the output stream
    void writeUnit(
      std::pair< AutoPtr<ParsingContext>, AutoPtr<Blueprint> > parsed,
      const Algorithm::t_instantiation_context& ictx,
      std::ostream&                            _out,
      bool                                      first_pass);

    /// \brief parses a specific unit
    std::pair< AutoPtr<ParsingContext>, AutoPtr<Blueprint> > parseUnit(std::string to_parse);

    /// \brief returns the static blueprint for 'unit', otherwise null
    AutoPtr<Blueprint> isStaticBlueprint(std::string unit);

    /// \brief get the list of blueprints (after parsing)
    const std::unordered_map<std::string, AutoPtr<Blueprint> > getBlueprints() const
      { return m_Blueprints; }

  };

  // -------------------------------------------------

};
