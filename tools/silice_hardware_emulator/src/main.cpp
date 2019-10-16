
#include <LibSL/LibSL.h>
#include <LibSL/LibSL_gl.h>

#include "VgaChip.h"
#include "VCDParser.h"

LIBSL_WIN32_FIX;

// ---------------------------------------------------------------------

void main_render()
{
  glClearColor(0,0,1,0);
  glClear(GL_COLOR_BUFFER_BIT);
}

// ---------------------------------------------------------------------

int main(int argc,char **argv)
{

  if (argc < 2) {
    std::cerr << "Please provide vcd file as argument" << std::endl;
    return -1;
  }

  std::string infile(argv[1]);
  VCDParser vcp(infile);

  //VCDFileParser parser;
  //VCDFile *trace = parser.parse_file(infile);
  //if (!trace) {
  //  std::cerr << "parsing error." << std::endl;
  //  return -1;
  //}

  VgaChip vga;

  SimpleUI::init(vga.w(),vga.h(),"Silice Hardware Emulator");

  SimpleUI::onRender = main_render;

  /*
  LibSL::CppHelpers::Console::progressTextInit(trace->get_timestamps()->size());
  for (VCDTime time : *trace->get_timestamps()) {
    LibSL::CppHelpers::Console::progressTextUpdate();

    VCDValue *val_clk    = trace->get_signal_value_at( clk   ->hash, time);
    VCDValue *val_vga_hs = trace->get_signal_value_at( vga_hs->hash, time);
    VCDValue *val_vga_vs = trace->get_signal_value_at( vga_vs->hash, time);
    VCDValue *val_vga_r  = trace->get_signal_value_at( vga_r ->hash, time);
    VCDValue *val_vga_g  = trace->get_signal_value_at( vga_g ->hash, time);
    VCDValue *val_vga_b  = trace->get_signal_value_at( vga_b ->hash, time);
    
    vga.eval(
      val_clk   ->get_value_bit(), 
      val_vga_vs->get_value_bit(), 
      val_vga_hs->get_value_bit(), 
      toUInt8(val_vga_r->get_value_vector()), 
      toUInt8(val_vga_g->get_value_vector()), 
      toUInt8(val_vga_b->get_value_vector())
    );
  }
  LibSL::CppHelpers::Console::progressTextEnd();
  */

  glDisable(GL_DEPTH_TEST);

  SimpleUI::loop();

  SimpleUI::shutdown();

  return -1;
}

// ---------------------------------------------------------------------

