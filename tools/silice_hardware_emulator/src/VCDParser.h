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
// SL 2019-10-16
// ------------------------------------------------------
#pragma once

#include <LibSL/LibSL.h>
#include <unordered_map>

// ------------------------------------------------------

class VCDParser
{
private:

  /// \brief typedefs on parser for convenience
  typedef LibSL::BasicParser::FileStream                             t_stream;
  typedef LibSL::BasicParser::Parser<LibSL::BasicParser::FileStream> t_parser;
  typedef AutoPtr<t_stream> t_stream_ptr;
  typedef AutoPtr<t_parser> t_parser_ptr;
  
  /// \brief stream (file)
  t_stream_ptr m_Stream;
  /// \brief parser
  t_parser_ptr m_Parser;

  /// \brief decosed a value into a 64 bits integer
  uint64_t decodeValue(std::string v);

  /// \brief from name to hash
  std::unordered_map<std::string, std::string> m_Name2Hash;
  /// \brief from hash to name
  std::unordered_map<std::string, std::string> m_Hash2Name;
  /// \brief stores current signal values
  std::unordered_map<std::string, uint64_t>    m_VarValues;

public:

  /// \brief initializes streaming through the vcd file
  VCDParser(std::string fname);

  /// \brief steps to the next timestamp, returns the timestamp value or -1 if end of file
  int step();

  /// \brief returns the current value of a signal
  uint64_t value(std::string name) const { 
    auto N = m_Name2Hash.find(name);
    if (N == m_Name2Hash.end()) {
      throw Fatal("could not find signal '%s'",name.c_str());
    }
    return m_VarValues.at(N->second);
  }
};

// ------------------------------------------------------
