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

#include "SiliceCompiler.h"

#include <string>
#include <iostream>
#include <fstream>
#include <regex>
#include <queue>

#include <LibSL/LibSL.h>

#include <tclap/CmdLine.h>
#include <tclap/UnlabeledValueArg.h>

using namespace Silice;

// -------------------------------------------------

int main(int argc, char **argv)
{
  try {

    TCLAP::CmdLine cmd(
      "<< Silice to Verilog compiler >>\n"
      "(c) Sylvain Lefebvre -- @sylefeb\n"
      "Under Affero GPL License, source code on https://github.com/sylefeb/Silice\n"
      , ' ', "0.1");

    TCLAP::UnlabeledValueArg<std::string> source("source", "Input source file (.ice)", true, "","string");
    cmd.add(source);
    TCLAP::ValueArg<std::string> output("o", "output", "Output compiled file (.v)", false, "out.v", "string");
    cmd.add(output);
    TCLAP::ValueArg<std::string> framework("f", "framework", "Input framework file (.v)", false, "../frameworks/icarus_bare.v", "string");
    cmd.add(framework);

    cmd.parse(argc, argv);

    SiliceCompiler compiler;
    compiler.run(
      source.getValue().c_str(),
      output.getValue().c_str(),
      framework.getValue().c_str());

  } catch (TCLAP::ArgException& err) {
    std::cerr << "command line error: " << err.what() << std::endl;
    return -1;
  } catch (Fatal& err) {
    std::cerr << Console::red << "error: " << err.message() << Console::gray << std::endl;
    return -2;
  } catch (std::exception& err) {
    std::cerr << "error: " << err.what() << std::endl;
    return -3;
  }
  return 0;
}

// -------------------------------------------------
