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

// -------------------------------------------------

/// \brief LUA based Pre-processor 
class LppPreProcessor
{
private:

  std::string processCode(std::string src_file) const;

public:

  LppPreProcessor();
  virtual ~LppPreProcessor();

  void execute(std::string src_file, std::string dst_file) const;

};

// -------------------------------------------------
