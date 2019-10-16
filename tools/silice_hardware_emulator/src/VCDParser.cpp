// SL 2019-10-16
// ------------------------------------------------------

#include "VCDParser.h"

// ------------------------------------------------------

// ------------------------------------------------------

VCDParser::VCDParser(std::string fname)
{

  m_Stream = t_stream_ptr(new t_stream(fname.c_str()));
  m_Parser = t_parser_ptr(new t_parser(*m_Stream, true));

  int line = 0;
  
  while (!m_Parser->eof()) {
    line++;

    std::string s = m_Parser->readString();
    if (s == "$var") {
      std::string type = m_Parser->readString();
      int         size = m_Parser->readInt();
      std::string hash = m_Parser->readString();
      std::string name = m_Parser->readString();
      std::cerr << type << " " << size << " " << hash << " " << name << std::endl;
    } else if (s == "$scope") {
      m_Parser->readString();
      std::string scope_name = m_Parser->readString();
       std::cerr << "scope " << scope_name << std::endl;
    } else if (s == "$dumpvars") {
      // read initial values

      // stop here!
      break;
    }

  }

}

// ------------------------------------------------------
