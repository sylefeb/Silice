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

LppPreProcessor::LppPreProcessor()
{

}

// -------------------------------------------------

LppPreProcessor::~LppPreProcessor()
{

}

// -------------------------------------------------

std::map<lua_State*, std::ofstream> g_LuaOutputs;

static void lua_output(lua_State *L,std::string str)
{
  g_LuaOutputs[L] << str;
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
      luabind::def("output", &lua_output)
    ];
}

// -------------------------------------------------

static std::string luaProtectString(std::string str)
{
  str = regex_replace(str, regex("\'"), "\\'");
  return str;
}

// -------------------------------------------------

std::string LppPreProcessor::processCode(std::string src_file) const
{
  cerr << "preprocessing " << src_file << '.' << endl;
  if (!LibSL::System::File::exists(src_file.c_str())) {
    throw Fatal("cannot find source file '%s'", src_file.c_str());
  }
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
    }
  }

  return code;
}

// -------------------------------------------------

void LppPreProcessor::execute(std::string src_file, std::string dst_file) const
{
  lua_State *L = luaL_newstate();

  g_LuaOutputs.insert(std::make_pair(L, ofstream(dst_file)));

  bindScript(L);

  std::string code = processCode(src_file);

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
      errmsg = matches.str(2).c_str();
    }
    cerr << Console::yellow;
    cerr << errline << "] " << errmsg << endl;
    cerr << Console::gray;
  }

  g_LuaOutputs.at(L).close();
  g_LuaOutputs.erase(L);

  lua_close(L);
}

// -------------------------------------------------
