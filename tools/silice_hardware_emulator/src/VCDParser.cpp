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

#include "VCDParser.h"
#include <queue>

// ------------------------------------------------------

// TODO support for x,z

uint64_t VCDParser::decodeValue(std::string v)
{
  uint64_t val = 0;
  if (v.length() == 1) {
    val = (v[0] == '1') ? 1 : 0;
  }
  if (v[0] == 'b') {
    ForRange(i, 1, v.length() - 1) {
      val = (val << 1) | (v[i] == '1' ? 1 : 0);
    }
  }
  return val;
}

// ------------------------------------------------------

VCDParser::VCDParser(std::string fname)
{
  m_Stream = t_stream_ptr(new t_stream(fname.c_str()));
  m_Parser = t_parser_ptr(new t_parser(*m_Stream, true));

  std::vector<std::string> scopes;

  int line = 0;
  
  while (!m_Parser->eof()) {
    line++;

    std::string s = m_Parser->readString();
    if (s == "$var") {
      std::string type = m_Parser->readString();
      int         size = m_Parser->readInt();
      if (size > 64) {
        throw Fatal("signals above 64 bits width are not yet supported");
      }
      std::string hash = m_Parser->readString();
      std::string name = m_Parser->readString();
      std::string prefix;
      for (auto s : scopes) {
        prefix = prefix + ":" + s;
      }
      name = prefix + ":" + name;
      std::cerr << "signal: " << type << " " << name << " " << size << " (" << hash << ")"  << std::endl;
      m_VarValues.insert(make_pair(name,0));
      m_Hash2Name.insert(make_pair(hash,name));
      m_Name2Hash.insert(make_pair(name,hash));
    } else if (s == "$scope") {
      m_Parser->readString();
      std::string scope_name = m_Parser->readString();
      std::cerr << "scope: " << scope_name << std::endl;
      scopes.push_back(scope_name);
    } else if (s == "$upscope") {
      scopes.pop_back();
    } else if (s == "$dumpvars") {
      // read initial values
      while (true) {
        // read value
        std::string val = m_Parser->readString(NULL, "b01xz");
        if (val == "") {
          // check for end
          std::string end = m_Parser->readString();
          if (end != "$end") {
            throw Fatal("expected $end to close section $dumpvars");
          }
          // stop here!
          return;
        }
        // read hash
        std::string hash = m_Parser->readString();
        // decode and store
        m_VarValues[hash] = decodeValue(val);
        // std::cerr << m_Hash2Name[hash] << " = " << m_VarValues[hash] << std::endl;
      }
    }

  }

}

// ------------------------------------------------------

int VCDParser::step()
{
  std::string tm_stamp = m_Parser->readString();
  if (tm_stamp[0] != '#') {
    throw Fatal("expected timestamp to start with a #");
  }
  int tm = atoi(tm_stamp.substr(1).c_str());
  // std::cerr << "==== timestamp " << tm << " ====" << std::endl;
  while (!m_Parser->eof()) {
    // read value
    std::string val = m_Parser->readString(NULL, "b01xz");
    if (val == "") {
      char c = m_Parser->readChar(false);
      if (c != '#') {
        throw Fatal("expected timestamp to start with a #");
      }    
      // stop here!
      return tm;
    }
    // read hash
    std::string hash = m_Parser->readString();
    // decode and store
    m_VarValues[hash] = decodeValue(val);
    // std::cerr << m_Hash2Name[hash] << " = " << m_VarValues[hash] << std::endl;
  }
  return -1;
}

// ------------------------------------------------------
