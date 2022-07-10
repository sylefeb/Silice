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
#include <unordered_set>
#include <map>

#include <LibSL/Math/Vertex.h>

#include "Blueprint.h"

struct lua_State;

namespace Silice {

  // -------------------------------------------------

  /// \brief LUA based Pre-processor
  class LuaPreProcessor
  {
  private:

    /// \brief records where a unit is located in the input stream
    typedef struct {
      int start;
      int end;
      int io_start;
      int io_end;
    } t_unit_loc;

    /// \brief Assembles the code into a single file, removing includes
    std::string assembleSource(std::string parent_path, std::string src_file, std::unordered_set<std::string> alreadyIncluded,int& _output_line_count);
    ///  \brief Decomposes the source into blueprints
    void decomposeSource(const std::string& incode, std::map<int, std::pair<std::string, t_unit_loc> >& _units);

    /// \brief Prepare the code to be processed with Lua
    std::string prepareCode(std::string header,const std::string& incode, const std::map<int, std::pair<std::string, t_unit_loc> >& units);

    /// \brief Finds an included file, testing all search paths
    std::string findFile(std::string path, std::string fname) const;

    lua_State                         *m_LuaState = nullptr;

    std::map<int, std::pair<std::string, t_unit_loc> > m_Units;
    std::set<std::string>              m_FormalUnits;

    std::vector<std::string>           m_SearchPaths;
    std::map<std::string, std::string> m_Definitions;

    int                                m_CurOutputLine = 0;
    std::vector<std::string>           m_Files;
    std::vector<LibSL::Math::v3i>      m_SourceFilesLineRemapping; // [0] is line in output, [1] is source file id, [2] is line in source
    std::string                        m_FilesReportName;   // if empty, no files report, otherwise name of the report

    void createLuaContext();
    void destroyLuaContext();
    void executeLuaString(std::string lua_code, std::string dst_file, bool has_ictx, const Blueprint::t_instantiation_context& ictx);

  public:

    LuaPreProcessor();
    virtual ~LuaPreProcessor();
    /// \brief generates the body source code in file dst_file
    void generateBody(std::string src_file, const std::vector<std::string> &defaultLibraries,
                      const Blueprint::t_instantiation_context& ictx, std::string lua_header_code, std::string dst_file);
    /// \brief generates a unit IO source code (the part defining unit ios) in dst_file
    void generateUnitIOSource(std::string unit, std::string dst_file);
    /// \brief generates a unit source code in dst_file
    void generateUnitSource(std::string unit, std::string dst_file, const Blueprint::t_instantiation_context& ictx);

    std::vector<std::string> searchPaths() const { return m_SearchPaths; }

    void addDefinition(std::string def, std::string value) { m_Definitions[def] = value; }

    std::string findFile(std::string fname) const;

    std::pair<std::string, int> lineAfterToFileAndLineBefore_search(int line,const std::vector<LibSL::Math::v3i>& remap) const;
    std::pair<std::string, int> lineAfterToFileAndLineBefore(ParsingContext *pctx,int line) const;

    void addingLines(int num, int src_line, int src_file);

    void enableFilesReport(std::string fname);

    /// \brief returns the list of formal unit names
    const std::set<std::string>& formalUnits() { return m_FormalUnits; }
  };

  // -------------------------------------------------

};
