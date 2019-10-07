#pragma once
// -------------------------------------------------
//
// FPGA Simple Language
//
// (c) Sylvain Lefebvre 2019
// 
//                                ... hardcoding ...
// -------------------------------------------------
/*

*/

#include <string>

// -------------------------------------------------

using namespace std;

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
