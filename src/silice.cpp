// -------------------------------------------------
//
// Silice FPGA language
//
// (c) Sylvain Lefebvre 2019
// 
//                                ... code hard! ...
// -------------------------------------------------
/*

*/

#include "VerilogCompiler.h"

#include <string>
#include <iostream>
#include <fstream>
#include <regex>
#include <queue>

#include <LibSL/LibSL.h>

#include "path.h"

#include <tclap/CmdLine.h>
#include <tclap/UnlabeledValueArg.h>

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
    TCLAP::ValueArg<std::string> framework("f", "framework", "Input framework file (.v)", false, "../frameworks/mojo_basic.v", "string");
    cmd.add(framework);

    cmd.parse(argc, argv);

    VerilogCompiler compiler;
    compiler.run(
      source.getValue().c_str(),
      output.getValue().c_str(),
      framework.getValue().c_str());

  } catch (TCLAP::ArgException& err) {
    cerr << "command line error: " << err.what() << endl;
  } catch (Fatal& err) {
    cerr << Console::red << "error: " << err.message() << Console::gray << endl;
  } catch (std::exception& err) {
    cerr << "error: " << err.what() << endl;
  }
}

// -------------------------------------------------
