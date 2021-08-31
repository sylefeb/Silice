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

#include <LibSL/Math/Vertex.h>

namespace Silice {

  // -------------------------------------------------

  /// \brief LUA based Pre-processor 
  class LuaPreProcessor
  {
  private:

    std::string processCode(std::string parent_path, std::string src_file, std::unordered_set<std::string> alreadyIncluded);
    std::string findFile(std::string path, std::string fname) const;

    std::vector<std::string>           m_SearchPaths;
    std::map<std::string, std::string> m_Definitions;

    int                                m_CurOutputLine = 0;
    std::vector<std::string>           m_Files;
    std::vector<LibSL::Math::v3i>      m_FileLineRemapping; // [0] is line after, [1] is file id, [2] is line before

    std::string                        m_FilesReportName;   // if empty, no files report, otherwise name of the report

  public:

    LuaPreProcessor();
    virtual ~LuaPreProcessor();

    void run(std::string src_file, const std::vector<std::string> &defaultLibraries, std::string lua_header_code, std::string dst_file);

    std::vector<std::string> searchPaths() const { return m_SearchPaths; }

    void addDefinition(std::string def, std::string value) { m_Definitions[def] = value; }

    std::string findFile(std::string fname) const;

    std::pair<std::string, int> lineAfterToFileAndLineBefore(int line_after) const;

    void addingLines(int num, int src_line, int src_file);

    void enableFilesReport(std::string fname);

  };

  // -------------------------------------------------

};
