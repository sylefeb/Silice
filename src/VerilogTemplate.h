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
/*
  The replacement format in the template is %VAR_NAME%
  Digits are not allowed in var names
*/
// -------------------------------------------------

#include <unordered_map>
#include <string>

/// \brief Handles a code template in Verilog
class VerilogTemplate
{
private:

  /// \brief code with replacement done
  std::string m_Code;
 
public:  

  /// \brief default constructor
  VerilogTemplate() { }

  /// \brief load the template and applies the variable replacements
  void load(std::string fname, 
       const std::unordered_map<std::string,std::string>& keyValues);

  /// \brief returns the processed code       
  const std::string& code() const { return m_Code; }
  
};

// -------------------------------------------------
