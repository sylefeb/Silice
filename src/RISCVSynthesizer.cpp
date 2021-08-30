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

#include <LibSL.h>

// -------------------------------------------------

using namespace Silice;
using namespace std;

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

string RISCVSynthesizer::generateCHeader(siliceParser::RiscvContext *riscv) const
{
  ostringstream header;
  for (auto io : riscv->inOutList()->inOrOut()) {
    auto input  = dynamic_cast<siliceParser::InputContext *>   (io->input());
    auto output = dynamic_cast<siliceParser::OutputContext *>  (io->output());
    auto inout  = dynamic_cast<siliceParser::InoutContext *>   (io->inout());
    if (input) {
      header << "volatile int *__ptr__" << input->IDENTIFIER()->getText() << "=(int*)0x10000" << ';' << nxl; // TODO
      header << "static inline int " << input->IDENTIFIER()->getText() << "() { " 
             << "return *__ptr__" << input->IDENTIFIER()->getText() << "; }" << nxl;
    } else if (output) {
      sl_assert(output->declarationVar()->IDENTIFIER() != nullptr); // TODO: proper check
      header << "volatile int *__ptr__" << output->declarationVar()->IDENTIFIER()->getText() << "=(int*)0x10000" << ';' << nxl; // TODO
      header << "static inline void " << output->declarationVar()->IDENTIFIER()->getText() << "(int v) { "
        << "*__ptr__" << output->declarationVar()->IDENTIFIER()->getText() << "=v; }" << nxl;
    } else if (inout) {

    } else {
      sl_assert(false); // RISC-V supports only input/output/inout   TODO error message
    }
  }
  return header.str();
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
    string tempfile = std::tmpnam(nullptr);
    tempfile = tempfile + ".c";
    {
      ofstream codefile(tempfile);
      // append code header
      codefile << generateCHeader(riscv);
      // user provided code
      codefile << ccode << endl;
    }
    for (auto &c : tempfile) {
      if (c == '\\') c = '/';
    }
    // compile source code
    string cmd =
        string(LibSL::System::Application::executablePath())
      + "/silice.exe "
      + CONFIG.keyValues()["libraries_path"] + "/riscv/riscv-compile-rv32e.ice "
      + "-D SRC=\"\\\"" + tempfile + "\\\"\" "
      + "-D CRT0=\"\\\"" + CONFIG.keyValues()["libraries_path"] + "/riscv/crt0.s" + "\\\"\" "
      + "-D LD_CONFIG=\"\\\"" + CONFIG.keyValues()["libraries_path"] + "/riscv/config_c.ld" + "\\\"\" "
      + "--framework " + CONFIG.keyValues()["frameworks_dir"] + "/boards/bare/bare.v "
      ;
    system(cmd.c_str());
  }
}

// -------------------------------------------------
