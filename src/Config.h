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

#include <unordered_map>
#include <string>

/// \brief Singleton that contains the global configuration
///        for the Silice compiler
class Config
{
private:

  std::unordered_map<std::string,std::string> m_KeyValues;

  static Config *s_UniqueInstance;
  
  Config();
  
public:  
  
  std::unordered_map<std::string,std::string>& keyValues()             { return m_KeyValues; }
  const std::unordered_map<std::string,std::string>& keyValues() const { return m_KeyValues; }

  void print();

  static Config *getUniqueInstance();
  
};

// -------------------------------------------------

#define CONFIG (*Config::getUniqueInstance())

// -------------------------------------------------
