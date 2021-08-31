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

#include "RISCVSynthesizer.h"
#include "Config.h"
#include "Utils.h"

#include <LibSL.h>

// -------------------------------------------------

using namespace std;
using namespace Silice;
using namespace Silice::Utils;

// -------------------------------------------------

antlr4::TokenStream *RISCVSynthesizer::s_TokenStream = nullptr;

// -------------------------------------------------

std::string RISCVSynthesizer::extractCodeBetweenTokens(std::string file, int stk, int etk) const
{
  int sidx = (int)s_TokenStream->get(stk)->getStartIndex();
  int eidx = (int)s_TokenStream->get(etk)->getStopIndex();
  FILE *f = NULL;
  fopen_s(&f, file.c_str(), "rb");
  if (f) {
    char buffer[256];
    fseek(f, sidx, SEEK_SET);
    int read = (int)fread(buffer, 1, min(255, eidx - sidx + 1), f);
    buffer[read] = '\0';
    fclose(f);
    return std::string(buffer);
  }
  return s_TokenStream->getText(s_TokenStream->get(stk), s_TokenStream->get(etk));
}

// -------------------------------------------------

std::string RISCVSynthesizer::cblockToString(siliceParser::CblockContext *cblock) const
{
  std::string file = s_TokenStream->getTokenSource()->getInputStream()->getSourceName();
  return extractCodeBetweenTokens(file, (int)cblock->getSourceInterval().a, (int)cblock->getSourceInterval().b);
}

// -------------------------------------------------

int RISCVSynthesizer::memorySize(siliceParser::RiscvContext *riscv) const
{
  if (riscv->riscvModifiers() != nullptr) {
    for (auto m : riscv->riscvModifiers()->riscvModifier()) {
      if (m->rmemsz() != nullptr) {
        int sz = atoi(m->rmemsz()->NUMBER()->getText().c_str());
        if (sz <= 0 || (sz%4) != 0) {
          reportError(riscv->getSourceInterval(), -1, "[RISCV] memory size (in bytes) should be > 0 and multiple of four (got %d).",sz);
        }
        return sz;
        break;
      }
    }
  }
  reportError(riscv->getSourceInterval(), -1, "[RISCV] no memory size specified, please use a modifier e.g. <mem=1024>");
  return 0;
}

// -------------------------------------------------

string RISCVSynthesizer::generateCHeader(siliceParser::RiscvContext *riscv) const
{
  
  // NOTE TODO: error checking for width and non supported IO types, additional error reporting

  ostringstream header;
  // bit indicating an IO (first after useful address width)
  int periph_bit = justHigherPow2(memorySize(riscv));
  // base address for input/outputs
  int ptr_base   = 1 << (periph_bit + 1);
  int ptr_next   = 1; // bit for the next IO
  for (auto io : riscv->inOutList()->inOrOut()) {
    auto input  = dynamic_cast<siliceParser::InputContext *>   (io->input());
    auto output = dynamic_cast<siliceParser::OutputContext *>  (io->output());
    auto inout  = dynamic_cast<siliceParser::InoutContext *>   (io->inout());
    string addr = string("=(int*)0x") + string(sprint("%x", ptr_base | ptr_next));
    if (input) {
      header << "volatile int *__ptr__" << input->IDENTIFIER()->getText() << addr << ';' << nxl;
      // getter
      header << "static inline int " << input->IDENTIFIER()->getText() << "() { " 
             << "return *__ptr__" << input->IDENTIFIER()->getText() << "; }" << nxl;
    } else if (output) {
      sl_assert(output->declarationVar()->IDENTIFIER() != nullptr); // TODO: error message
      header << "volatile int *__ptr__" << output->declarationVar()->IDENTIFIER()->getText() << addr << ';' << nxl;
      // setter
      header << "static inline void " << output->declarationVar()->IDENTIFIER()->getText() << "(int v) { "
        << "*__ptr__" << output->declarationVar()->IDENTIFIER()->getText() << "=v; }" << nxl;
    } else if (inout) {
      header << "volatile int *__ptr__" << inout->IDENTIFIER()->getText() << addr << ';' << nxl; // TODO
      // getter
      header << "static inline int " << inout->IDENTIFIER()->getText() << "() { "
        << "return *__ptr__" << inout->IDENTIFIER()->getText() << "; }" << nxl;
      // setter
      header << "static inline void " << inout->IDENTIFIER()->getText() << "(int v) { "
        << "*__ptr__" << inout->IDENTIFIER()->getText() << "=v; }" << nxl;
    } else {
      sl_assert(false); // RISC-V supports only input/output/inout   TODO error message
    }
    ptr_next = ptr_next << 2;
    if (ptr_next >= ptr_base) {
      reportError(riscv->getSourceInterval(), -1, "[RISCV] address bust not wide enough for the number of input/outputs (one bit per IO is required)");
    }
  }
  return header.str();
}

// -------------------------------------------------

string RISCVSynthesizer::generateSiliceCode(siliceParser::RiscvContext *riscv) const
{
  string io_decl;
  string io_select;
  string io_reads  = "{32{1b1}}";
  string io_writes;
  int idx = 0;
  for (auto io : riscv->inOutList()->inOrOut()) {
    auto input  = dynamic_cast<siliceParser::InputContext *>   (io->input());
    auto output = dynamic_cast<siliceParser::OutputContext *>  (io->output());
    auto inout  = dynamic_cast<siliceParser::InoutContext *>   (io->inout());
    io_select   = io_select + "uint1 io_" + std::to_string(idx) + " <:: prev_mem_addr[" + std::to_string(idx) + ",1]; ";
    string v;
    if (input) {
      v         = input->IDENTIFIER()->getText();
      io_reads  = io_reads  + " | (io_" + std::to_string(idx) + " ? " + v + " : 32b0)";
      io_decl   = "input ";
    } else if (output) {
      v         = output->declarationVar()->IDENTIFIER()->getText();
      io_writes = io_writes + v + " = io_" + std::to_string(idx) + " ? memio.wdata : " + v + "; ";
      io_decl   = "output ";
    } else if (inout) {
      v         = inout->IDENTIFIER()->getText();
      // NOTE: not so simple, has to be a true inout ...
      //io_reads  = io_reads + " | (io_" + std::to_string(idx) + " ? " + v + " : 32b0)";
      //io_writes = io_writes + v + " = io_" + std::to_string(idx) + " ? memio.wdata : " + v + "\n$$";
      io_decl   = "inout ";
      reportError(inout->getSourceInterval(), -1, "inout not yet supported");
    } else {
      // TODO error message, actual checks!
      reportError(inout->getSourceInterval(), -1, "[RISC-V] only 32bits input / output are support");
    }
    io_decl += "uint32 " + v + ',';
    ++ idx;
  }
  ostringstream code;
  code << "$$dofile('" << CONFIG.keyValues()["libraries_path"] + "/riscv/riscv-compile.lua');" << nxl;
  code << "$$addrW     = " << 1+justHigherPow2(memorySize(riscv)) << nxl;
  code << "$$memsz     = " << memorySize(riscv)/4 << nxl;
  code << "$$meminit   = data_bram" << nxl;
  code << "$$external  = " << justHigherPow2(memorySize(riscv)) << nxl;
  code << "$$io_decl   = [[" << io_decl << "]]" << nxl;
  code << "$$io_select = [[" << io_select << "]]" << nxl;
  code << "$$io_reads  = [[" << io_reads << "]]" << nxl;
  code << "$$io_writes = [[" << io_writes << "]]" << nxl;
  code << "$include(\"" << CONFIG.keyValues()["libraries_path"] + "/riscv/riscv-ice-v-soc.ice\");" << nxl;
  return code.str();
}

// -------------------------------------------------

static void normalizePath(string& _path)
{
  for (auto &c : _path) {
    if (c == '\\') c = '/';
  }
}

// -------------------------------------------------

RISCVSynthesizer::RISCVSynthesizer(siliceParser::RiscvContext *riscv)
{
  string name = riscv->IDENTIFIER()->getText();
  if (riscv->riscvInstructions()->initList() != nullptr) {    
    // table initializer with instructions
    sl_assert(false); // TODO
  } else {
    // compile from inline source
    sl_assert(riscv->riscvInstructions()->cblock() != nullptr);
    string ccode = cblockToString(riscv->riscvInstructions()->cblock());
    ccode = ccode.substr(1, ccode.size() - 2); // skip braces
    // write code to temp file
    string c_tempfile;
    {
      c_tempfile = std::tmpnam(nullptr);
      c_tempfile = c_tempfile + ".c";
      ofstream codefile(c_tempfile);
      // append code header
      codefile << generateCHeader(riscv);
      // user provided code
      codefile << ccode << endl;
    }
    // generate Silice source
    string s_tempfile;
    {
      s_tempfile = std::tmpnam(nullptr);
      s_tempfile = s_tempfile + ".ice";
      // produce source code
      ofstream silicefile(s_tempfile);
      silicefile << generateSiliceCode(riscv);
    }
    // compile Silice source
    normalizePath(c_tempfile);
    normalizePath(s_tempfile);
    string cmd =
        string(LibSL::System::Application::executablePath())
      + "/silice.exe "
      + "-o " + name + ".v "
      + s_tempfile + " "
      + "-D SRC=\"\\\"" + c_tempfile + "\\\"\" "
      + "-D CRT0=\"\\\"" + CONFIG.keyValues()["libraries_path"] + "/riscv/crt0.s" + "\\\"\" "
      + "-D LD_CONFIG=\"\\\"" + CONFIG.keyValues()["libraries_path"] + "/riscv/config_c.ld" + "\\\"\" "
      + "--framework " + CONFIG.keyValues()["frameworks_dir"] + "/boards/bare/bare.v "
      ;
    system(cmd.c_str());
  }
}

// -------------------------------------------------
