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

#include "SiliceCompiler.h"

#include <string>
#include <iostream>
#include <fstream>
#include <regex>
#include <queue>

#include <LibSL/LibSL.h>

#if defined (__wasi__)
#define throw // NOTE: heavy handed approach to disabling exceptions, with the
        // constructors exiting with an error message (see TCLAP::ArgException)
#endif
#include <tclap/CmdLine.h>
#include <tclap/UnlabeledValueArg.h>

#include "version.inc"

using namespace Silice;

// -------------------------------------------------
// global switches

extern bool g_Disable_CL0006;
extern bool g_ForceResetInit;
extern bool g_SplitInouts;

// -------------------------------------------------


int main(int argc, char **argv)
{

  try {

    const std::string version_string = std::string(" 1.0.11") + " " + c_GitHash;
    //                                               ^ ^ ^
    //                                               | | |
    //                                               | | \_ increments with features in wip/draft (x.x.x)
    //                                               | \_ increments with features in master (x.x.0)
    //                                               \_ increments on releases (x.0.0)

    TCLAP::CmdLine cmd(
      "<< Silice to Verilog compiler >>\n"
      "(c) Sylvain Lefebvre -- @sylefeb\n"
      "Under GPLv3 license, see LICENSE_GPLv3 in Silice repo root, source code on https://github.com/sylefeb/Silice\n"
      ,' ', version_string.c_str());

    TCLAP::UnlabeledValueArg<std::string> source("source", "Input source file (.si)", true, "","string");
    cmd.add(source);
    TCLAP::ValueArg<std::string> output("o", "output", "Output compiled file (.v)", false, "out.v", "string");
    cmd.add(output);
    TCLAP::ValueArg<std::string> framework("f", "framework", "Input framework file (.v)", true, "", "string");
    cmd.add(framework);
    TCLAP::ValueArg<std::string> frameworks_dir("", "frameworks_dir", "Path to frameworks root directory", false, "", "string");
    cmd.add(frameworks_dir);
    TCLAP::MultiArg<std::string> defines("D", "define", "specifies a define for the preprocessor, e.g. -D name=value\nthe define is added both to the Silice preprocessor and the Verilog framework header", false, "string");
    cmd.add(defines);
    TCLAP::MultiArg<std::string> configs("C", "config", "specifies a config option, e.g. -C name=value", false, "string");
    cmd.add(configs);
    TCLAP::ValueArg<std::string> toExport("", "export", "Name of the algorithm to export (ignores main when specified)", false, "", "string");
    cmd.add(toExport);
    TCLAP::MultiArg<std::string> exportParam("P", "export_param", "specifies an export parameter for algorithm instantiation, e.g. -P name=value", false, "string");
    cmd.add(exportParam);
    TCLAP::SwitchArg             forceResetInit("", "force-reset-init", "forces initialization at reset of initialized registers", false);
    cmd.add(forceResetInit);
    TCLAP::SwitchArg             disableCL0006("", "no-pin-check", "force disable check for pin declaration in frameworks (see CL0006)", false);
    cmd.add(disableCL0006);
    TCLAP::SwitchArg             splitInouts("", "split-inouts", "splits all inouts into enable, in, out pins", false);
    cmd.add(splitInouts);
    TCLAP::ValueArg<std::string> top("", "top", "Name of the top module in generated Verilog", false, "top", "string");
    cmd.add(top);

    cmd.parse(argc, argv);

    g_Disable_CL0006 = disableCL0006.getValue();
    g_ForceResetInit = forceResetInit.getValue();
    g_SplitInouts    = splitInouts.getValue();

    SiliceCompiler compiler;

    compiler.run(
      source.getValue(),
      output.getValue(),
      framework.getValue(),
      frameworks_dir.getValue(),
      defines.getValue(),
      configs.getValue(),
      toExport.getValue(),
      exportParam.getValue(),
      top.getValue());

  } catch (TCLAP::ArgException& err) {
    std::cerr << "command line error: " << err.what() << "\n";
    return -1;
  } catch (Fatal& err) {
    std::cerr << Console::red << "error: " << err.message() << Console::gray << "\n";
    return -2;
  } catch (std::exception& err) {
    std::cerr << "error: " << err.what() << "\n";
    return -3;
  }

  return 0;
}

// -------------------------------------------------
