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
// -------------------------------------------------
//                                ... hardcoding ...
// -------------------------------------------------
#include "lppLexer.h"
#include "lppParser.h"
// -------------------------------------------------
#include "LuaPreProcessor.h"
// -------------------------------------------------

#include <iostream>
#include <fstream>
#include <regex>
#include <queue>

#include <LibSL/LibSL.h>

#include "path.h"

using namespace std;
using namespace antlr4;

// -------------------------------------------------

#include "tga.h"

// -------------------------------------------------

extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}
#include <luabind/luabind.hpp>
#include <luabind/adopt_policy.hpp>
#include <luabind/operator.hpp>
#include <luabind/exception_handler.hpp>

// -------------------------------------------------

LuaPreProcessor::LuaPreProcessor()
{

}

// -------------------------------------------------

LuaPreProcessor::~LuaPreProcessor()
{

}

// -------------------------------------------------

std::string LuaPreProcessor::findFile(std::string path, std::string fname) const
{
  std::string tmp_fname;

  if (LibSL::System::File::exists(fname.c_str())) {
    return fname;
  }
  tmp_fname = path + "/" + extractFileName(fname);
  if (LibSL::System::File::exists(tmp_fname.c_str())) {
    return tmp_fname;
  }
  tmp_fname = path + "/" + fname;
  if (LibSL::System::File::exists(tmp_fname.c_str())) {
    return tmp_fname;
  }
  return fname;
}

// -------------------------------------------------

std::string LuaPreProcessor::findFile(std::string fname) const
{
  for (const auto& path : m_SearchPaths) {
    fname = findFile(path, fname);
  }
  return fname;
}

// -------------------------------------------------

std::map<lua_State*, std::ofstream>    g_LuaOutputs;
std::map<lua_State*, LuaPreProcessor*> g_LuaPreProcessors;

// -------------------------------------------------

static void lua_output(lua_State *L,std::string str)
{
  g_LuaOutputs[L] << str;
}

// -------------------------------------------------

static void lua_preproc_error(lua_State *L, std::string str)
{
  // std::cerr << Console::yellow << str << Console::gray << endl;
  lua_error(L);
}

// -------------------------------------------------

static void lua_print(lua_State *L, std::string str)
{
  cerr << "[preprocessor] " << Console::white << str << Console::gray << endl;
}

// -------------------------------------------------

static void lua_image_table(lua_State* L, std::string str)
{
  auto P = g_LuaPreProcessors.find(L);
  if (P == g_LuaPreProcessors.end()) {
    throw Fatal("internal error (lua_image_table)");
  }
  LuaPreProcessor *lpp   = P->second;
  std::string      fname = lpp->findFile(str);
  t_image_nfo* nfo = ReadTGAFile(fname.c_str());
  if (nfo == NULL) {
    throw Fatal("cannot load image file '%s'",fname.c_str());
  }
  int    nc  = nfo->depth/8;
  uchar* ptr = nfo->pixels;
  ForIndex(j, nfo->height) {
    ForIndex(i, nfo->width) {
      uint32_t v = 0;
      ForIndex(c, nc) {
        v = (v << 8) | *(uint8_t*)(ptr++);
      }
      g_LuaOutputs[L] << std::to_string(v) << ",";
    }
  }
  delete[](nfo->pixels);
  if (nfo->colormap) {
    delete[](nfo->colormap);
  }
  delete (nfo);
}

// -------------------------------------------------

static void lua_palette_table(lua_State* L, std::string str)
{
  auto P = g_LuaPreProcessors.find(L);
  if (P == g_LuaPreProcessors.end()) {
    throw Fatal("internal error (lua_image_table)");
  }
  LuaPreProcessor *lpp = P->second;
  std::string      fname = lpp->findFile(str);
  t_image_nfo* nfo = ReadTGAFile(fname.c_str());
  if (nfo == NULL) {
    throw Fatal("cannot load image file '%s'", fname.c_str());
  }
  if (nfo->colormap == NULL) {
    throw Fatal("image file '%s' has no palette", fname.c_str());
  }
  if (nfo->depth != 8) {
    throw Fatal("image file '%s' palette is not 8 bits", fname.c_str());
  }
  uchar* ptr = nfo->colormap;
  ForIndex(idx, 256) {
      uint32_t v = 0;
      ForIndex(c, 3) {
        v = (v << 8) | *(uint8_t*)(ptr++);
      }
      g_LuaOutputs[L] << std::to_string(v) << ",";
  }
  delete[](nfo->pixels);
  if (nfo->colormap) {
    delete[](nfo->colormap);
  }
  delete (nfo);
}

// -------------------------------------------------

static void bindScript(lua_State *L)
{
  luabind::open(L);

  lua_pushcfunction(L, luaopen_base);
  lua_pushliteral(L, "");
  lua_call(L, 1, 0);

  lua_pushcfunction(L, luaopen_math);
  lua_pushliteral(L, LUA_TABLIBNAME);
  lua_call(L, 1, 0);

  lua_pushcfunction(L, luaopen_table);
  lua_pushliteral(L, LUA_TABLIBNAME);
  lua_call(L, 1, 0);

  lua_pushcfunction(L, luaopen_string);
  lua_pushliteral(L, LUA_TABLIBNAME);
  lua_call(L, 1, 0);

  luabind::module(L)
    [
      luabind::def("print",         &lua_print),
      luabind::def("error",         &lua_preproc_error),
      luabind::def("output",        &lua_output),
      luabind::def("image_table",   &lua_image_table),
      luabind::def("palette_table", &lua_palette_table)
    ];
}

// -------------------------------------------------

static std::string luaProtectString(std::string str)
{
  str = regex_replace(str, regex("\'"), "\\'");
  return str;
}

// -------------------------------------------------

std::string LuaPreProcessor::processCode(
  std::string parent_path,
  std::string src_file,
  std::unordered_set<std::string> alreadyIncluded)
{
  cerr << "preprocessing " << src_file << '.' << endl;
  if (!LibSL::System::File::exists(src_file.c_str())) {
    throw Fatal("cannot find source file '%s'", src_file.c_str());
  }
  if (alreadyIncluded.find(src_file) != alreadyIncluded.end()) {
    throw Fatal("source file '%s' already included (cyclic dependency)", src_file.c_str());
  }

  // add to already included
  alreadyIncluded.insert(src_file);

  // extract path
  std::string fpath = extractPath(src_file);
  if (fpath == src_file) {
    fpath = ".";
  }
  std::string path  = parent_path + fpath;
  //cerr << "parent_path: " << parent_path << endl;
  //cerr << "path:        " << path << endl;

  m_SearchPaths.push_back(path);

  ifstream          file(src_file);

  ANTLRInputStream  input(file);
  lppLexer          lexer(&input);
  CommonTokenStream tokens(&lexer);
  lppParser         parser(&tokens);

  std::string code = "";

  for (auto l : parser.root()->line()) {
    if (l->lualine() != nullptr) {
      code += l->lualine()->code->getText() + "\n";
    } else if (l->siliceline() != nullptr) {
      code += "output('";
      for (auto c : l->siliceline()->children) {
        auto silcode = dynamic_cast<lppParser::SilicecodeContext*>(c);
        auto luacode = dynamic_cast<lppParser::LuacodeContext*>(c);
        if (silcode) {
          code += luaProtectString(silcode->getText());
        }
        if (luacode) {
          code += "' .. " + luacode->code->getText() + " .. '";
        }
      }
      code += "\\n')\n";
    } else if (l->siliceincl() != nullptr) {
      std::string filename = l->siliceincl()->filename->getText();
      std::regex  lfname_regex("\\s*\\(\\s*\\'([a-zA-Z_0-9\\./]+)\\'\\s*\\)\\s*");
      std::smatch matches;
      if (std::regex_match(filename, matches, lfname_regex)) {
        std::string fname = matches.str(1).c_str();
        fname             = findFile(path, fname);
        // recurse
        code += "\n" + processCode(path + "/",fname, alreadyIncluded) + "\n";
      }

    }
  }

  return code;
}

// -------------------------------------------------

void LuaPreProcessor::run(std::string src_file, std::string header_code, std::string dst_file)
{
  lua_State *L = luaL_newstate();

  g_LuaOutputs.insert(std::make_pair(L, ofstream(dst_file)));
  g_LuaPreProcessors.insert(std::make_pair(L, this));

  // bind intrisics
  bindScript(L);

  // bind definitions
  for (auto dv : m_Definitions) {
    luabind::globals(L)[dv.first] = dv.second;
  }

  // get code
  std::unordered_set<std::string> inclusions;
  std::string code = 
    header_code +
    processCode("", src_file, inclusions);

  int ret = luaL_dostring(L, code.c_str());
  if (ret) {
    char str[4096];
    int errline = -1;
    std::string errmsg = lua_tostring(L, -1);
    snprintf(str, 4049, "[[LUA]exit] %s", errmsg.c_str());
    std::regex  lnum_regex(".*\\:([[:digit:]]+)\\:(.*)");
    std::smatch matches;
    if (std::regex_match(errmsg, matches, lnum_regex)) {
      errline = atoi(matches.str(1).c_str());
      errmsg  = matches.str(2).c_str();
    }
    cerr << "[preprocessor] ";
    cerr << Console::yellow;
    if (errline > -1) {
      cerr << errline << "] " << errmsg << endl;
    } else {
      cerr << errmsg << endl;
    }
    cerr << Console::gray;
  }

  g_LuaOutputs.at(L).close();
  g_LuaOutputs.erase(L);
  g_LuaPreProcessors.erase(L);

  lua_close(L);

}

// -------------------------------------------------
