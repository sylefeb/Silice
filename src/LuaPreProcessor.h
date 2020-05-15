/*

    Silice FPGA language and compiler
    (c) Sylvain Lefebvre - @sylefeb

This work and all associated files are under the

     GNU AFFERO GENERAL PUBLIC LICENSE
        Version 3, 19 November 2007
        
A copy of the license full text is included in 
the distribution, please refer to it for details.

(header_1_0)
*/
#pragma once
// -------------------------------------------------
//                                ... hardcoding ...
// -------------------------------------------------

#include <string>
#include <unordered_set>

#include <LibSL/Math/Vertex.h>

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

public:

  LuaPreProcessor();
  virtual ~LuaPreProcessor();

  void run(std::string src_file, std::string header_code, std::string dst_file);

  std::vector<std::string> searchPaths() const { return m_SearchPaths; }
  
  void addDefinition(std::string def, std::string value) { m_Definitions[def] = value; }

  std::string findFile(std::string fname) const;

  std::pair<std::string,int> lineAfterToFileAndLineBefore(int line_after) const;

  void addingLines(int num,int src_line, int src_file);

};

// -------------------------------------------------
