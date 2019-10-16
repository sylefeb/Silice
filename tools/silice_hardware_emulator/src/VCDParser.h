// SL 2019-10-16
// ------------------------------------------------------
#pragma once

#include <LibSL/LibSL.h>

// ------------------------------------------------------

class VCDParser
{
private:

  typedef LibSL::BasicParser::FileStream                             t_stream;
  typedef LibSL::BasicParser::Parser<LibSL::BasicParser::FileStream> t_parser;

  typedef AutoPtr<t_stream> t_stream_ptr;
  typedef AutoPtr<t_parser> t_parser_ptr;
  
  t_stream_ptr m_Stream;
  t_parser_ptr m_Parser;


public:

  VCDParser(std::string fname);
};

// ------------------------------------------------------
