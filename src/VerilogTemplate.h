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
