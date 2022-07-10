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
// -------------------------------------------------
//                                ... hardcoding ...
// -------------------------------------------------
#include "LuaPreProcessor.h"
#include "ParsingContext.h"
#include "Config.h"
#include "Utils.h"
// -------------------------------------------------

#include <iostream>
#include <fstream>
#include <regex>
#include <queue>
#include <filesystem>

#include <LibSL/LibSL.h>

#ifndef EOF
#define EOF -1
#endif
#include <LibSL/CppHelpers/BasicParser.h>

using namespace std;
using namespace antlr4;
using namespace Silice;

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

static void load_config_into_lua(lua_State *L)
{
  luabind::object table = luabind::newtable(L);
  for (auto kv : CONFIG.keyValues()) {
    table[kv.first] = kv.second;
  }
  luabind::globals(L)["config"] = table;
}

// -------------------------------------------------

static void load_config_from_lua(lua_State *L)
{
  luabind::object table = luabind::globals(L)["config"];
  for (luabind::iterator kv(table), end; kv != end; kv++) {
    string key   = luabind::object_cast_nothrow<string>(kv.key(),string(""));
    string value = luabind::object_cast_nothrow<string>(*kv, string(""));
    CONFIG.keyValues()[key] = value;
  }
}

// -------------------------------------------------

LuaPreProcessor::LuaPreProcessor()
{

}

// -------------------------------------------------

LuaPreProcessor::~LuaPreProcessor()
{
  destroyLuaContext();
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

std::map<lua_State*, std::ofstream>                      g_LuaOutputs;
std::map<lua_State*, Blueprint::t_instantiation_context> g_LuaInstCtx;
std::map<lua_State*, LuaPreProcessor*>                   g_LuaPreProcessors;

// -------------------------------------------------

static void lua_output(lua_State *L,std::string str,int src_line, int src_file)
{
  auto P = g_LuaPreProcessors.find(L);
  if (P == g_LuaPreProcessors.end()) {
    lua_pushliteral(L, "[preprocessor] internal error");
    lua_error(L);
  }
  P->second->addingLines(Utils::numLinesIn(str), src_line, src_file);
  g_LuaOutputs[L] << str;
}

// -------------------------------------------------

void LuaPreProcessor::addingLines(int num, int src_line,int src_file)
{
  ParsingContext::activeContext()->lineRemapping.push_back(v3i(m_CurOutputLine, src_file, src_line));
  m_CurOutputLine += num;
}

// -------------------------------------------------

static void lua_preproc_error(lua_State *L, std::string str)
{
  lua_error(L);
}

// -------------------------------------------------

static void lua_print(lua_State *L, std::string str)
{
  cerr << "[preprocessor] " << Console::white << str << Console::gray << "\n";
}

// -------------------------------------------------

int lua_widthof(lua_State *L, std::string var)
{
  auto C = g_LuaInstCtx.find(L);
  if (C == g_LuaInstCtx.end()) {
    lua_pushfstring(L, "[preprocessor] cannot call widthof on '%s', widthof is only allowed in the unit body", var.c_str());
    lua_error(L);
  }
  std::string key = var;
  std::transform(key.begin(), key.end(), key.begin(),
    [](unsigned char c) -> unsigned char { return std::toupper(c); });
  key = key + "_WIDTH";
  if (C->second.parameters.count(key) == 0) {
    lua_pushfstring(L, "[preprocessor] widthof, cannot find io '%s' in instantiation context",var.c_str());
    lua_error(L);
  } else {
    return atoi(C->second.parameters.at(key).c_str());
  }
  return 0;
}

// -------------------------------------------------

bool lua_signed(lua_State *L, std::string var)
{
  auto C = g_LuaInstCtx.find(L);
  if (C == g_LuaInstCtx.end()) {
    lua_pushfstring(L, "[preprocessor] cannot call signed on '%s', signed is only allowed in the unit body", var.c_str());
    lua_error(L);
  }
  std::string key = var;
  std::transform(key.begin(), key.end(), key.begin(),
    [](unsigned char c) -> unsigned char { return std::toupper(c); });
  key = key + "_SIGNED";
  if (C->second.parameters.count(key) == 0) {
    lua_pushfstring(L, "[preprocessor] signed, cannot find io '%s' in instantiation context", var.c_str());
    lua_error(L);
  } else {
    return C->second.parameters.at(key) == "signed";
  }
  return false;
}

// -------------------------------------------------

void lua_dofile(lua_State *L, std::string str)
{
  auto P = g_LuaPreProcessors.find(L);
  if (P == g_LuaPreProcessors.end()) {
    lua_pushliteral(L, "[preprocessor] internal error");
    lua_error(L);
  }
  LuaPreProcessor *lpp   = P->second;
  std::string      fname = lpp->findFile(str);
  int ret = luaL_dofile(L, fname.c_str());
  if (ret) {
    lua_error(L);
  }
}

// -------------------------------------------------

std::string lua_findfile(lua_State *L, std::string str)
{
  auto P = g_LuaPreProcessors.find(L);
  if (P == g_LuaPreProcessors.end()) {
    lua_pushliteral(L, "[findfile] internal error");
    lua_error(L);
  }
  LuaPreProcessor *lpp   = P->second;
  std::string      fname = lpp->findFile(str);
  return fname;
}

// -------------------------------------------------

static void lua_write_image_in_table(lua_State* L, std::string str,int component_depth)
{
  auto P = g_LuaPreProcessors.find(L);
  if (P == g_LuaPreProcessors.end()) {
    lua_pushliteral(L, "[write_image_in_table] internal error");
    lua_error(L);
  }
  if (component_depth < 0 || component_depth > 8) {
    lua_pushliteral(L, "[write_image_in_table] component depth can only in ]0,8]");
    lua_error(L);
  }
  LuaPreProcessor *lpp   = P->second;
  std::string      fname = lpp->findFile(str);
  t_image_nfo     *nfo   = ReadTGAFile(fname.c_str());
  if (nfo == NULL) {
    lua_pushfstring(L, "[write_image_in_table] cannot load image file '%s'",fname.c_str());
    lua_error(L);
  }
  int    nc  = nfo->depth/8;
  uchar* ptr = nfo->pixels;
  ForIndex(j, nfo->height) {
    ForIndex(i, nfo->width) {
      uint32_t v = 0;
      ForIndex(c, nc) {
        v = (v << component_depth) | ((*(uint8_t*)(ptr++) >> (8 - component_depth)) & ((1 << component_depth) - 1));
      }
      g_LuaOutputs[L] << std::to_string(v) << ",";
    }
  }
  delete[](nfo->pixels);
  delete[](nfo->colormap);
  delete (nfo);
}

static void lua_write_image_in_table_simple(lua_State* L, std::string str)
{
  lua_write_image_in_table(L, str, 8);
}

// -------------------------------------------------

static void lua_write_palette_in_table(lua_State* L, std::string str, int component_depth)
{
  auto P = g_LuaPreProcessors.find(L);
  if (P == g_LuaPreProcessors.end()) {
    lua_pushliteral(L, "[write_palette_in_table] internal error");
    lua_error(L);
  }
  if (component_depth < 0 || component_depth > 8) {
    lua_pushliteral(L, "[write_palette_in_table] component depth can only in ]0,8]");
    lua_error(L);
  }
  LuaPreProcessor *lpp   = P->second;
  std::string      fname = lpp->findFile(str);
  t_image_nfo     *nfo   = ReadTGAFile(fname.c_str());
  if (nfo == NULL) {
    lua_pushfstring(L, "[write_palette_in_table] cannot load image file '%s'", fname.c_str());
    lua_error(L);
  }
  if (nfo->colormap == NULL) {
    lua_pushfstring(L, "[write_palette_in_table] image file '%s' has no palette", fname.c_str());
    lua_error(L);
  }
  if (nfo->depth != 8) {
    lua_pushfstring(L, "[write_palette_in_table] image file '%s' palette is not 8 bits", fname.c_str());
    lua_error(L);
  }
  if (nfo->colormap_chans != 3) {
    lua_pushfstring(L, "[write_palette_in_table] image file '%s' palette is not RGB", fname.c_str());
    lua_error(L);
  }
  uchar* ptr = nfo->colormap;
  ForIndex(idx, 256) {
      uint32_t v = 0;
      if ((uint)idx < nfo->colormap_size) {
        ForIndex(c, 3) {
          v = (v << component_depth) | ((*(uint8_t *)(ptr++) >> (8 - component_depth)) & ((1 << component_depth) - 1));
        }
      }
      g_LuaOutputs[L] << std::to_string(v) << ",";
  }
  delete[](nfo->pixels);
  delete[](nfo->colormap);
  delete (nfo);
}

// -------------------------------------------------

static void lua_write_palette_in_table_simple(lua_State* L, std::string str)
{
  lua_write_palette_in_table(L, str, 8);
}

// -------------------------------------------------

static luabind::object lua_get_palette_as_table(lua_State* L, std::string str, int component_depth)
{
  auto P = g_LuaPreProcessors.find(L);
  if (P == g_LuaPreProcessors.end()) {
    lua_pushliteral(L, "[get_palette_as_table] internal error");
    lua_error(L);
  }
  if (component_depth < 0 || component_depth > 8) {
    lua_pushliteral(L, "[get_palette_as_table] component depth can only be in ]0,8]");
    lua_error(L);
  }
  LuaPreProcessor *lpp   = P->second;
  std::string      fname = lpp->findFile(str);
  t_image_nfo     *nfo   = ReadTGAFile(fname.c_str());
  if (nfo == NULL) {
    lua_pushfstring(L, "[get_palette_as_table] cannot load image file '%s'", fname.c_str());
    lua_error(L);
  }
  if (nfo->colormap == NULL) {
    lua_pushfstring(L, "[get_palette_as_table] image file '%s' has no palette", fname.c_str());
    lua_error(L);
  }
  if (nfo->depth != 8) {
    lua_pushfstring(L, "[get_palette_as_table] image file '%s' palette is not 8 bits", fname.c_str());
    lua_error(L);
  }
  if (nfo->colormap_chans != 3) {
    lua_pushfstring(L, "[write_palette_in_table] image file '%s' palette is not RGB", fname.c_str());
    lua_error(L);
  }
  luabind::object ltbl = luabind::newtable(L);
  uchar* ptr = nfo->colormap;
  ForIndex(idx, 256) {
    uint32_t v = 0;
    if ((uint)idx < nfo->colormap_size) {
      ForIndex(c, 3) {
        v = (v << component_depth) | ((*(uint8_t *)(ptr++) >> (8 - component_depth)) & ((1 << component_depth) - 1));
      }
    }
    ltbl[1 + idx] = v;
  }
  delete[](nfo->pixels);
  delete[](nfo->colormap);
  delete (nfo);
  return ltbl;
}

// -------------------------------------------------

static luabind::object lua_get_palette_as_table_simple(lua_State *L, std::string str)
{
  return lua_get_palette_as_table(L, str, 8);
}

// -------------------------------------------------

static luabind::object lua_get_image_as_table(lua_State* L, std::string str, int component_depth)
{
  auto P = g_LuaPreProcessors.find(L);
  if (P == g_LuaPreProcessors.end()) {
    lua_pushliteral(L, "[get_image_as_table] internal error");
    lua_error(L);
  }
  if (component_depth < 0 || component_depth > 8) {
    lua_pushliteral(L, "[get_image_as_table] component depth can only be in ]0,8]");
    lua_error(L);
  }
  LuaPreProcessor *lpp   = P->second;
  std::string      fname = lpp->findFile(str);
  t_image_nfo     *nfo = ReadTGAFile(fname.c_str());
  if (nfo == NULL) {
    lua_pushfstring(L, "[get_image_as_table] cannot load image file '%s'", fname.c_str());
    lua_error(L);
  }
  luabind::object rows = luabind::newtable(L);
  int    nc = nfo->depth / 8;
  uchar* ptr = nfo->pixels;
  ForIndex(j, nfo->height) {
    luabind::object cols = luabind::newtable(L);
    ForIndex(i, nfo->width) {
      uint32_t v = 0;
      ForIndex(c, nc) {
        v = (v << component_depth) | ((*(uint8_t*)(ptr++) >> (8 - component_depth)) & ((1 << component_depth) - 1));
      }
      cols[1 + i] = v;
    }
    rows[1 + j] = cols;
  }
  delete[](nfo->pixels);
  delete[](nfo->colormap);
  delete (nfo);
  return rows;
}

// -------------------------------------------------

static luabind::object lua_get_image_as_table_simple(lua_State *L, std::string str)
{
  return lua_get_image_as_table(L, str, 8);
}

// -------------------------------------------------

void lua_save_table_as_image(lua_State *L, luabind::object tbl, std::string fname)
{
  try {
    int i = 0, j = 0;
    int w = 0, h = 0;
    // width / height
    for (luabind::iterator row(tbl), end; row != end; row++) {
      int ncol = 0;
      for (luabind::iterator col(*row), end; col != end; col++) {
        ++ncol;
      }
      if (w != 0 && w != ncol) {
        lua_pushfstring(L, "[save_table_as_image] row %d does not have the same size as previous", j);
        lua_error(L);
      }
      w = ncol;
      ++h;
      ++j;
    }
    // pixels
    ImageRGB img(w,h);
    j = 0;
    for (luabind::iterator row(tbl), end; row != end; row++) {
      i = 0;
      for (luabind::iterator col(*row), end; col != end; col++) {
        int pix = luabind::object_cast_nothrow<int>(*col,0);
        img.pixel(i, j) = v3b((pix) & 255, (pix >> 8) & 255, (pix >> 16) & 255);
        ++i;
      }
      ++j;
    }
    // save
    saveImage(fname.c_str(), &img);
  } catch (Fatal& f) {
    luaL_error(L,f.message());
  }
}

// -------------------------------------------------

void lua_save_table_as_image_with_palette(lua_State *L,
  luabind::object tbl, luabind::object palette, std::string fname)
{
  try {
    int i = 0, j = 0;
    int w = 0, h = 0;
    // width / height
    for (luabind::iterator row(tbl), end; row != end; row++) {
      int ncol = 0;
      for (luabind::iterator col(*row), end; col != end; col++) {
        ++ncol;
      }
      if (w != 0 && w != ncol) {
        lua_pushfstring(L, "[save_table_as_image_with_palette] row %d does not have the same size as previous", j);
        lua_error(L);
      }
      w = ncol;
      ++h;
      ++j;
    }
    // pixels
    Array2D<uchar> pixs;
    pixs.allocate(w, h);
    j = 0;
    for (luabind::iterator row(tbl), end; row != end; row++) {
      i = 0;
      for (luabind::iterator col(*row), end; col != end; col++) {
        int pix = luabind::object_cast_nothrow<int>(*col, 0);
        pixs.at(i, j) = pix;
        ++i;
      }
      ++j;
    }
    // palette
    i = 0;
    Array<uint> pal(256);
    for (luabind::iterator p(palette), end; p != end; p++) {
      uint clr = luabind::object_cast_nothrow<uint>(*p, 0);
      if (i == 256) {
        lua_pushliteral(L, "[save_table_as_image_with_palette] palette has too many entries (expects 256)");
        lua_error(L);
      }
      pal[i++] = (clr >> 16) | (((clr >> 8) & 255) << 8) | ((clr & 255) << 16);
    }
    if (i < 256) {
      lua_pushliteral(L, "[save_table_as_image_with_palette] palette is missing entries (expects 256)");
      lua_error(L);
    }
    // save
#pragma pack(push, 1)
    /* TGA header */
    struct tga_header_t
    {
      uchar id_length;          /* size of image id */
      uchar colormap_type;      /* 1 if has a colormap */
      uchar image_type;         /* compression type */

      short	cm_first_entry;       /* colormap origin */
      short	cm_length;            /* colormap length */
      uchar cm_depth;            /* colormap depth */

      short	x_origin;             /* bottom left x coord origin */
      short	y_origin;             /* bottom left y coord origin */

      short	width;                /* picture width (in pixels) */
      short	height;               /* picture height (in pixels) */

      uchar pixel_depth;        /* bits per pixel: 8, 16, 24 or 32 */
      uchar image_descriptor;   /* 24 bits = 0x00; 32 bits = 0x80 */
    };
#pragma pack(pop)
    FILE *f = NULL;
    fopen_s(&f, fname.c_str(), "wb");
    if (f == NULL) {
      lua_pushfstring(L, "sorry, cannot write file '%s'", fname.c_str());
      lua_error(L);
    }
    struct tga_header_t hd;
    hd.id_length = 0;
    hd.colormap_type = 1;
    hd.image_type = 1;
    hd.cm_first_entry = 0;
    hd.cm_length = 256;
    hd.cm_depth = 24;
    hd.x_origin = 0;
    hd.y_origin = 0;
    hd.width = w;
    hd.height = h;
    hd.pixel_depth = 8;
    hd.image_descriptor = (1 << 5);
    fwrite(&hd, sizeof(struct tga_header_t), 1, f);
    ForIndex(p, pal.size()) {
      fwrite(&pal[p], 3, 1, f);
    }
    fwrite(pixs.raw(), w*h, 1, f);
    fclose(f);

  } catch (Fatal& f) {
    luaL_error(L, f.message());
  }
}

// -------------------------------------------------

int lua_lshift(int n,int s)
{
  return n << s;
}

int lua_rshift(int n, int s)
{
  return n >> s;
}

int lua_clog2(int w)
{
  return Utils::justHigherPow2(w);
}

// -------------------------------------------------

static void bindScript(lua_State *L)
{
  luabind::open(L);

  luaL_openlibs(L);

  luabind::module(L)
    [
      luabind::def("print", &lua_print),
      luabind::def("error", &lua_preproc_error),
      luabind::def("output", &lua_output),
      luabind::def("dofile", &lua_dofile),
      luabind::def("findfile", &lua_findfile),
      luabind::def("write_image_in_table", &lua_write_image_in_table),
      luabind::def("write_image_in_table", &lua_write_image_in_table_simple),
      luabind::def("write_palette_in_table", &lua_write_palette_in_table),
      luabind::def("write_palette_in_table", &lua_write_palette_in_table_simple),
      luabind::def("get_image_as_table", &lua_get_image_as_table),
      luabind::def("get_image_as_table", &lua_get_image_as_table_simple),
      luabind::def("get_palette_as_table", &lua_get_palette_as_table),
      luabind::def("get_palette_as_table", &lua_get_palette_as_table_simple),
      luabind::def("save_table_as_image", &lua_save_table_as_image),
      luabind::def("save_table_as_image_with_palette", &lua_save_table_as_image_with_palette),
      luabind::def("clog2",         &lua_clog2),
      luabind::def("lshift",        &lua_lshift),
      luabind::def("rshift",        &lua_rshift),
      luabind::def("widthof",       &lua_widthof),
      luabind::def("signed",        &lua_signed)
    ];
}

// -------------------------------------------------

static std::string luaProtectString(std::string str)
{
  str = regex_replace(str, regex("\'"), "\\'");
  return str;
}

// -------------------------------------------------

std::string robustExtractPath(const std::string& path)
{
  // search for last '\\' or '/'
  size_t pos0 = path.rfind("\\");
  size_t pos1 = path.rfind("/");
  size_t pos;
  if (pos0 == string::npos) {
    pos = pos1;
  } else if (pos1 == string::npos) {
    pos = pos0;
  } else {
    pos = max(pos0, pos1);
  }
  if (pos == string::npos) {
    return path;
  }
  string dname = path.substr(0, pos);
  return dname;
}

// -------------------------------------------------

void LuaPreProcessor::enableFilesReport(std::string fname)
{
  m_FilesReportName = fname;
  // create report file, will delete if existing
  std::ofstream freport(m_FilesReportName);
}

// -------------------------------------------------

std::string LuaPreProcessor::assembleSource(
  std::string parent_path,
  std::string src_file,
  std::unordered_set<std::string> alreadyIncluded,
  int& _output_line_count)
{
  cerr << "assembling source " << src_file << '.' << "\n";
  if (!LibSL::System::File::exists(src_file.c_str())) {
    throw Fatal("cannot find source file '%s'", src_file.c_str());
  }
  if (alreadyIncluded.find(src_file) != alreadyIncluded.end()) {
    throw Fatal("source file '%s' already included (cyclic dependency)", src_file.c_str());
  }
  // generate a report with all the loaded files
  if (!m_FilesReportName.empty()) {
    std::ofstream freport(m_FilesReportName, std::ios_base::app);
    freport << std::filesystem::absolute(src_file).string() << '\n';
  }
  // add to already included
  alreadyIncluded.insert(src_file);
  // extract path
  std::string fpath = robustExtractPath(src_file);
  if (fpath == src_file) {
    fpath = ".";
  }
  std::string path = fpath;
  // add to search paths
  m_SearchPaths.push_back(path);
  // add to list of files
  m_Files.emplace_back(std::filesystem::absolute(src_file).string());
  int src_file_id = (int)m_Files.size() - 1;
  // parse, recurse on includes and read code
  LibSL::BasicParser::FileStream fs(src_file.c_str());
  LibSL::BasicParser::Parser<LibSL::BasicParser::FileStream> parser(fs,false);
  std::string code = "";
  int src_line = 0;
  while (!parser.eof()) {
    char next = parser.readChar(false);
    if (next == '$') {
      std::string w = parser.readString("(\n");
      if (w == "$include") {
        parser.readChar(true); // skip (
        auto next = parser.readChar();
        if (next != '"' && next != '\'') {
          // TODO: improve error report
          throw Fatal("parse error in include");
        }
        std::string fname = parser.readString("\"'");
        bool ok = parser.reachChar(')');
        if (!ok) {
          // TODO: improve error report
          throw Fatal("parse error in include");
        }
        // find file
        fname = findFile(path, fname);
        fname = findFile(fname);
        // recurse
        code += assembleSource(path + "/", fname, alreadyIncluded, _output_line_count);
      } else {
        code += " " + w;
      }
    } else if (IS_EOL(next)) {
      // code += " // " + std::to_string(_output_line_count) + " " + src_file + "::" + std::to_string(src_line);
      code += parser.readChar();
      m_SourceFilesLineRemapping.push_back(v3i(_output_line_count, src_file_id, src_line));
      ++ src_line;
      ++ _output_line_count;
    } else {
      std::string w = parser.readString();
      code += " " + w;
    }
  }
  return code;
}

// -------------------------------------------------

class BufferStream : public LibSL::BasicParser::BufferStream
{
public:
  BufferStream(const char *buffer, uint sz) : LibSL::BasicParser::BufferStream(buffer, sz) { }
  int& pos() { return m_Pos; }
  const char *buffer() const { return m_Buffer; }
};

typedef LibSL::BasicParser::Parser<LibSL::BasicParser::BufferStream> t_Parser;

// -------------------------------------------------

int jumpOverComment(t_Parser& parser, BufferStream& bs)
{
  parser.readChar();
  int next = parser.readChar(false);
  if (next == '/') {
    // comment, advance until next end of line
    parser.readString("\n");
    return 0;
  } else if (next == '*') {
    // block comment, find the end
    parser.readChar();
    int pos = bs.pos();
    while (!parser.eof()) {
      parser.reachChar('*');
      next = parser.readChar();
      if (next == '/') {
        int numlines = 0;
        for (int i = pos; i < bs.pos(); ++i) {
          if (bs.buffer()[i] == '\n') {
            ++numlines;
          }
        }
        return numlines;
      }
    }
    if (parser.eof()) {
      // TODO: improve error report
      throw Fatal("[parser] Reached end of file while parsing comment block");
    }
  } else {
    return -1; // not a comment
  }
  return 0;
}

// -------------------------------------------------

std::string jumpOverString(t_Parser& parser, BufferStream& bs)
{
  std::string str;
  parser.readChar();
  while (!parser.eof()) {
    std::string chunk = parser.readString("\"\\");
    int next = parser.readChar();
    if (next == '\\') {         // escape sequence
      str += chunk;
      str += "\\\\";            // add backslash
      str += parser.readChar(); // add whatever is afte
    } else if (next == '"') {
      return str + chunk;
    } else {
      str += chunk;
    }
  }
  // TODO: improve error report
  throw Fatal("[parser] Reached end of file while parsing string");
}

// -------------------------------------------------

/// \brief This class tracks how the preprocessor code selects
/// parts of the Silice code in the source file. We need to determine this
/// so we only count braces / spaces in one code path. This assumes
/// Lua if/then/else/elseif are only appearing in lua lines ($$),
/// which may not be strictly true but very likely to cover 99% of
/// cases (as using in between $...$ inserts requires advanced trickery.
/// Documentation should specify this.
/// This is also only considering Lua line comments, not the multiline version.
class LuaCodePath
{
private:
  std::vector<bool> m_IfSide;
public:
  LuaCodePath() {}
  void update(t_Parser& parser)
  {
    while (!parser.eof()) {
      int next = parser.readChar(false);
      if (IS_EOL(next)) {
        parser.readChar();
        return; // reached end of lua line
      } else if (next == '"' || next == '\'') {
        parser.readChar();
        // skip over string
        parser.reachChar(next);
      } else {
        std::string w = parser.readString(" \t\r\n\'\"");
        if (w == "--") { // line ends on comment
          return;
        } else if (w == "if" || w == "for" || w == "while" || w == "function") {
          if (m_IfSide.empty()) {
            m_IfSide.push_back(true);
          } else {
            m_IfSide.push_back(m_IfSide.back());
          }
        } else if (w == "end") {
          if (m_IfSide.empty()) {
            // TODO: better message!
            throw Fatal("[parser] Pre-processor directives are unbalanced within the unit, this is not supported.");
          }
          m_IfSide.pop_back();
        } else if (w == "else" || w == "elseif") {
          if (m_IfSide.empty()) {
            // TODO: better message!
            throw Fatal("[parser] Pre-processor directives are unbalanced within the unit, this is not supported.");
          }
          m_IfSide.pop_back();
          m_IfSide.push_back(false);
        }
      }
    }
  }
  bool consider() const { if (m_IfSide.empty()) return true; else return m_IfSide.back(); }
  int  nestLevel() const { return (int)m_IfSide.size(); }
};

// -------------------------------------------------

void processLuaLine(t_Parser& parser, LuaCodePath& lcp)
{
  parser.readChar();
  int next = parser.readChar(false);
  if (next == '$') {
    parser.readChar();
    // -> update the status
    lcp.update(parser);
  } else {
    // -> skip over Lua insert
    parser.reachChar('$');
  }
}

// -------------------------------------------------

void jumpOverNestedBlocks(t_Parser& parser, BufferStream& bs,LuaCodePath& lcp, char c_in, char c_out)
{
  int  inside = 0;
  while (!parser.eof()) {
    int next = parser.readChar(false);

    /* {
      int tmp = bs.pos();
      cerr << parser.readString() << "\n";
      bs.pos() = tmp;
    } */

    if (IS_EOL(next)) {
      parser.readChar();
    } else if (next == '\\') {
      // escape sequence, skip \ and next
      parser.readChar();
      parser.readChar();
    } else if (next == '$') { // NOTE: before '$' to avoid issues with Lua int div //
      // might be a Lua line
      processLuaLine(parser, lcp);
    } else if (next == '/') {
      // might be a comment, jump over it
      jumpOverComment(parser, bs);
    } else if (next == '"') {
      // string
      jumpOverString(parser, bs);
    } else if (next == c_in) {
      // entering a block
      parser.readChar();
      if (lcp.consider()) {
        //cerr << "==================== ++ (";
        ++inside;
        //cerr << inside << ")\n";
      }
    } else if (next == c_out) {
      // exiting a block
      parser.readChar();
      if (lcp.consider()) {
        //cerr << "==================== -- (";
        --inside;
        //cerr << inside << ")\n";
      }
      if (inside == 0) {
        // just exited
        return;
      }
    } else {
      parser.readChar();
    }
  }
  throw Fatal("[parser] Reached end of file while skipping blocks. Are %c %c unbalanced?",
               c_in,c_out);
}

// -------------------------------------------------

void jumpOverUnit(t_Parser& parser, BufferStream& bs, LuaCodePath& lcp, int& _io_start,int& _io_end)
{
  int nlvl_before = lcp.nestLevel();
  parser.skipSpaces();
  _io_start = bs.pos();
  jumpOverNestedBlocks(parser,bs, lcp, '(', ')');
  int nlvl_after_io = lcp.nestLevel();
  if (nlvl_before != nlvl_after_io) {
    throw Fatal("[parser] Pre-processor directives are spliting the unit io definitions, this is not supported:\n"
                "                A unit io definition has to be entirely contained within if-then-else directives");
  }
  _io_end   = bs.pos();
  jumpOverNestedBlocks(parser,bs, lcp, '{', '}');
  int nlvl_after  = lcp.nestLevel();
  if (nlvl_before != nlvl_after) {
    throw Fatal("[parser] Pre-processor directives are spliting the unit, this is not supported:\n"
                "                A unit has to be entirely contained within if-then-else directives");
  }
}

// -------------------------------------------------

void LuaPreProcessor::decomposeSource(
  const std::string& incode,
  std::map<int, std::pair<std::string, t_unit_loc> >& _units)
{
  BufferStream bs(incode.c_str(),(uint)incode.size());
  t_Parser     parser(bs, false);
  LuaCodePath  lcp;
  std::map<string, v2i> units;

  std::string code = "";
  while (!parser.eof()) {
    int next = parser.readChar(false);
    if (IS_EOL(next)) {
      parser.readChar();
    } else if (next == '$') {
      // might be a Lua line
      processLuaLine(parser, lcp);
    } else if (next == '/') {
      // might be a comment, jump over it
      jumpOverComment(parser, bs);
    } else {
      int before = bs.pos();
      std::string w = parser.readString(" \t\r/*");
      if (w == "unit" || w == "algorithm" || w == "algorithm#") {
        std::string name = parser.readString("( \t\r");
        cerr << "functionalizing unit " << name << '\n';
        if (w == "algorithm#") {
          m_FormalUnits.insert(name);
        }
        LuaCodePath lcp_unit;
        t_unit_loc  loc;
        loc.start = before;
        jumpOverUnit(parser,bs,lcp_unit,loc.io_start,loc.io_end);
        loc.end   = bs.pos();
        _units[before] = std::make_pair(name, loc);
      } else if (w.empty()) {
        parser.readChar();
      }
    }
  }
}

// -------------------------------------------------

std::string nameToLua(std::string str)
{
  BufferStream bs(str.c_str(), (uint)str.size());
  t_Parser     parser(bs, false);
  std::string  result;
  bool         first = true;
  while (!parser.eof()) {
    int next = parser.readChar(false);
    if (IS_EOL(next)) {
      sl_assert(false);
    } else if (next == '$') {
      // read until next $
      parser.readChar();
      std::string luacode = parser.readString("$");
      parser.readChar(); // skip $
      if (!first) {
        result += "..";
      }
      result += "(" + luacode + ")";
      first = false;
    } else {
      if (!first) {
        result += "..";
      }
      result += std::string("\'") + parser.readString("$") + std::string("\'");
      first = false;
    }
  }
  return result;
}

// -------------------------------------------------

std::string luaCodeSplit(std::string incode,int& _src_line)
{
  if (incode.empty()) return "";
  BufferStream bs(incode.c_str(), (uint)incode.size());
  t_Parser     parser(bs, false);
  std::string  code;
  std::string  current;
  while (!parser.eof()) {
    int next = parser.readChar(false);
    if (IS_EOL(next)) {
      // -> emit current
      if (!current.empty()) {
        code += "output('";
        code += current;
        code += "\\n'," + std::to_string(_src_line) + "," + std::to_string(0) + ")\n";
        current = "";
      }
      parser.readChar();
      ++_src_line;
    } else if (next == '\\') {
      // escape sequence
      parser.readChar();
      char ch = parser.readChar();
      current += "\\";
      current += ch;
    } else if (next == '/') {
      // might be a comment, jump over it
      int r = jumpOverComment(parser, bs);
      if (r >= 0) {
        _src_line += r;
      } else {
        current += next;
      }
    } else if (next == '"') {
      // string
      std::string str = jumpOverString(parser, bs);
      current += "\"" + str + "\"";
    } else if (next == '$') {
      // Lua line or insertion?
      parser.readChar();
      next = parser.readChar(false);
      if (next == '$') {
        // read line
        parser.readChar();
        std::string lualine = parser.readString("\n");
        code += lualine + "\n";
      } else {
        // read until next $
        std::string luacode = parser.readString("$");
        parser.readChar(); // skip $
        current += "' .. (" + luacode + ") .. '";
        if (incode[bs.pos()] == ' ') {
          current += " ";
        }
      }
    } else {
      current += luaProtectString(parser.readString("\\\r\n$ \""));
      if (incode[bs.pos()] == ' ') {
        current += " ";
      }
    }
  }
  // -> emit last
  if (!current.empty()) {
    code += "output('";
    code += current;
    code += "\\n'," + std::to_string(_src_line) + "," + std::to_string(0) + ")\n";
    current = "";
  }
  return code;
}

// -------------------------------------------------

std::string LuaPreProcessor::prepareCode(
  std::string header, const std::string& incode,
  const std::map<int, std::pair<std::string, t_unit_loc> >& units)
{
  cerr << "preprocessing " << "\n";
  std::string code = header;
  int src_line = 0;
  int prev = 0;
  for (auto u : m_Units) {
    std::string before = incode.substr(prev, u.second.second.start - prev);
    code += luaCodeSplit(before, src_line);
    // write input/output function
    code += "-- =================================>>> unit IO " + u.second.first + "\n";
    code += "_G[ '__io__' .. " + nameToLua(u.second.first) + "] = function()\n";
    std::string ios;
    for (int i = u.second.second.io_start + 1/*skip (*/; i < u.second.second.io_end - 1/*skip )*/; ++i) {
      ios += incode[i];
    }
    int io_src_line = src_line;
    code += luaCodeSplit(ios, io_src_line);
    code += "end\n";
    // write unit function
    code += "-- =================================>>> unit " + u.second.first + "\n";
    code += "_G[" + nameToLua(u.second.first) + "] = function()\n";
    std::string unit;
    for (int i = u.second.second.start; i < u.second.second.end; ++i) {
      unit += incode[i];
    }
    code += luaCodeSplit(unit, src_line);
    code += "end\n";
    code += "-- -----------------------------------\n";
    prev = u.second.second.end;
  }
  std::string last = incode.substr(prev);
  code += luaCodeSplit(last, src_line);
  return code;
}

// -------------------------------------------------

// NOTE: use std::filesystem::current_path() in the future ....
#if defined(WIN32) || defined(WIN64)

#include <direct.h>

std::string getCurrentPath()
{
  std::string ret;
  char buf[4096];
  ret = std::string(_getcwd(buf, 4096));
  return ret;
}

std::string fileAbsolutePath(std::string f)
{
  char buf[4096];
  GetFullPathNameA(f.c_str(), 4096, buf, NULL);
  return std::string(buf);
}

#else

#include <unistd.h>
#include <limits.h>

std::string getCurrentPath()
{
  std::string ret;
  char buf[PATH_MAX+1];
  ret = std::string(getcwd(buf, 4096));
  return ret;
}

std::string fileAbsolutePath(std::string f)
{
  char buf[PATH_MAX+1];
  realpath(f.c_str(), buf);
  return std::string(buf);
}

#endif

// -------------------------------------------------

void LuaPreProcessor::generateBody(
  std::string src_file,
  const std::vector<std::string>& defaultLibraries,
  const Blueprint::t_instantiation_context& ictx,
  std::string lua_header_code,
  std::string dst_file)
{
  // add current directory to search dirs
  m_SearchPaths.push_back(getCurrentPath());
  m_SearchPaths.push_back(extractPath(fileAbsolutePath(src_file)));

  // get code
  std::unordered_set<std::string> inclusions;
  // start with header
  std::string source_code = "";
  // add default libs to source
  int output_line_count = 0;
  for (auto l : defaultLibraries) {
    std::string libfile = CONFIG.keyValues()["libraries_path"] + "/" + l;
    libfile = findFile(libfile);
    source_code += assembleSource(CONFIG.keyValues()["libraries_path"], libfile, inclusions, output_line_count);
  }
  // parse main file
  source_code += assembleSource("", src_file, inclusions, output_line_count);

  {
    ofstream dbg(extractFileName(fileAbsolutePath(src_file) + ".pre.si"));
    dbg << source_code;
  }

  // decompose the soure into body and units
  decomposeSource(source_code, m_Units);
  // prepare the Lua code, with units as functions
  std::string lua_code = prepareCode(lua_header_code, source_code, m_Units);

  {
    ofstream dbg(extractFileName(fileAbsolutePath(src_file) + ".pre.lua"));
    dbg << lua_code;
  }

  // create Lua context
  createLuaContext();
  // execute body (Lua context also contains all unit functions)
  executeLuaString(lua_code, dst_file, false, ictx);

}

// -------------------------------------------------

void LuaPreProcessor::generateUnitIOSource(std::string unit, std::string dst_file)
{
  std::string lua_code = "_G['__io__" + unit + "']()\n";
  Blueprint::t_instantiation_context empty_ictx;
  executeLuaString(lua_code, dst_file, false, empty_ictx);
}

// -------------------------------------------------

void LuaPreProcessor::generateUnitSource(
  std::string unit, std::string dst_file, const Blueprint::t_instantiation_context& ictx)
{
  std::string lua_code = "_G['" + unit + "']()\n";
  executeLuaString(lua_code, dst_file, true, ictx);
}

// -------------------------------------------------

void LuaPreProcessor::createLuaContext()
{
  m_LuaState = luaL_newstate();
  g_LuaPreProcessors.insert(std::make_pair(m_LuaState, this));

  // bind intrisics
  bindScript(m_LuaState);

  // bind definitions
  for (auto dv : m_Definitions) {
    luabind::globals(m_LuaState)[dv.first] = dv.second;
  }

  load_config_into_lua(m_LuaState);
}

// -------------------------------------------------

void LuaPreProcessor::executeLuaString(std::string lua_code, std::string dst_file, bool has_ictx, const Blueprint::t_instantiation_context& ictx)
{
  // reset line counter
  m_CurOutputLine = 0;
  // prepare instantiation context
  if (has_ictx) {
    g_LuaInstCtx.insert(std::make_pair(m_LuaState, ictx));
  }
  // prepare output
  g_LuaOutputs.insert(std::make_pair(m_LuaState, ofstream(dst_file)));
  // execute
  int ret = luaL_dostring(m_LuaState, lua_code.c_str());
  if (ret) {
    char str[4096];
    int errline = -1;
    std::string errmsg = lua_tostring(m_LuaState, -1);
    snprintf(str, 4049, "[[LUA]exit] %s", errmsg.c_str());
    std::regex  lnum_regex(".*\\:([[:digit:]]+)\\:(.*)");
    std::smatch matches;
    if (std::regex_match(errmsg, matches, lnum_regex)) {
      errline = atoi(matches.str(1).c_str());
      errmsg = matches.str(2).c_str();
    }
    cerr << "[preprocessor] ";
    cerr << Console::yellow;
    if (errline > -1) {
      cerr << errline << "] " << errmsg << "\n";
    } else {
      cerr << errmsg << "\n";
    }
    cerr << Console::gray;
    throw Fatal("the preprocessor was interrupted");
  }
  // reload config
  load_config_from_lua(m_LuaState);
  // close output
  g_LuaOutputs.at(m_LuaState).close();
  g_LuaOutputs.erase(m_LuaState);
  if (has_ictx) {
    g_LuaInstCtx.erase(m_LuaState);
  }
}

// -------------------------------------------------

void LuaPreProcessor::destroyLuaContext()
{
  if (m_LuaState != nullptr) {
    g_LuaPreProcessors.erase(m_LuaState);
    lua_close(m_LuaState);
    m_LuaState = nullptr;
  }
}

// -------------------------------------------------

std::pair<std::string, int> LuaPreProcessor::lineAfterToFileAndLineBefore_search(int line, const std::vector<LibSL::Math::v3i>& remap) const
{
  if (line < 0) {
    return std::make_pair("", -1);
  }
  // locate line
  int l = 0, r = (int)remap.size()-1;
  while (l < r) {
    int m = (l + r) / 2;
    if (remap[m][0] < line) {
      l = m+1;
    } else if (remap[m][0] > line) {
      r = m;
    } else {
      return std::make_pair(m_Files[remap[m][1]], remap[m][2]);
    }
  }
  return std::make_pair(m_Files[remap[l][1]], remap[l][2]);
}

// -------------------------------------------------

std::pair<std::string, int> LuaPreProcessor::lineAfterToFileAndLineBefore(ParsingContext *pctx, int line) const
{
  auto prepro = lineAfterToFileAndLineBefore_search(line, pctx->lineRemapping);
  // NOTE: prepro.first is not used as this refers to the intermediate file
  return lineAfterToFileAndLineBefore_search(prepro.second, m_SourceFilesLineRemapping);
}

// -------------------------------------------------
