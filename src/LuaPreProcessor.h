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

// -------------------------------------------------

/// \brief LUA based Pre-processor 
class LuaPreProcessor
{
private:

  std::string processCode(std::string parent_path, std::string src_file, std::unordered_set<std::string> alreadyIncluded);
  std::string findFile(std::string path,std::string fname) const;

  std::vector<std::string>           m_SearchPaths;  
  std::map<std::string, std::string> m_Definitions;

public:

  LuaPreProcessor();
  virtual ~LuaPreProcessor();

  void run(std::string src_file, std::string header_code, std::string dst_file);

  std::vector<std::string> searchPaths() const { return m_SearchPaths; }
  
  void addDefinition(std::string def, std::string value) { m_Definitions[def] = value; }

};

// -------------------------------------------------
