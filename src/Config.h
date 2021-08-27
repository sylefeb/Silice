/*

    Silice FPGA language and compiler
    Copyright 2019, (C) Sylvain Lefebvre and contributors 

    List contributors with: git shortlog -n -s -- <filename>

    GPLv3 license

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

extern const std::string nxl; // end of line

// -------------------------------------------------
