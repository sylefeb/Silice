
#include <LibSL/LibSL.h>
#include <LibSL/LibSL_gl.h>

#include <thread>
#include <mutex>

#include "VgaChip.h"
#include "VCDParser.h"
#include "fstapi.h"

LIBSL_WIN32_FIX;

// ---------------------------------------------------------------------

// AutoPtr<VCDParser> g_VCD;
VgaChip            g_VGA;
Tex2DRGBA_Ptr      g_Tex;
void              *g_Wave = nullptr;

std::unordered_map<fstHandle, std::string> g_HandleToName;
std::unordered_map<std::string, uint64_t>  g_Values;

std::mutex         g_Mutex;

// ---------------------------------------------------------------------

void main_render()
{
  {
    std::unique_lock<std::mutex> lock(g_Mutex);

    glClearColor(0, 0, 1, 0);
    glClear(GL_COLOR_BUFFER_BIT);

    g_Tex = Tex2DRGBA_Ptr(new Tex2DRGBA(g_VGA.frameBuffer()->pixels(),GPUTEX_AUTOGEN_MIPMAP));

    glBindTexture(GL_TEXTURE_2D, g_Tex->handle());
    glEnable(GL_TEXTURE_2D);
    LibSL::GPUHelpers::Transform::ortho2D(LIBSL_PROJECTION_MATRIX, 0.0f, 1.0f, 1.0f, 0.0f);
    LibSL::GPUHelpers::Transform::identity(LIBSL_MODELVIEW_MATRIX);
    glColor3f(1, 1, 1);
    glBegin(GL_QUADS);
    glTexCoord2f(0.0f, 0.0f); glVertex2f(0.0f, 0.0f);
    glTexCoord2f(1.0f, 0.0f); glVertex2f(1.0f, 0.0f);
    glTexCoord2f(1.0f, 1.0f); glVertex2f(1.0f, 1.0f);
    glTexCoord2f(0.0f, 1.0f); glVertex2f(0.0f, 1.0f);
    glEnd();
  }

  std::this_thread::yield();
}

// ---------------------------------------------------------------------

uint64_t decodeValue(const char *str)
{
  uint64_t val = 0;
  while (*str != '\0') {
    val = (val << 1) | (*str == '1' ? 1 : 0);
    str++;
  }
  return val;
}

// ---------------------------------------------------------------------

void value_change_callback(void* user_callback_data_pointer, uint64_t time, fstHandle facidx, const unsigned char* value)
{
  std::unique_lock<std::mutex> lock(g_Mutex);

  g_Values[g_HandleToName[facidx]] = decodeValue((const char*)value);

  static bool prev_clk = false;
  bool clk = g_Values["clk"];
  if (clk != prev_clk) {
    prev_clk = clk;
    g_VGA.step(
      clk,
      g_Values["__main_vga_vs"],
      g_Values["__main_vga_hs"],
      g_Values["__main_vga_r [3:0]"],
      g_Values["__main_vga_g [3:0]"],
      g_Values["__main_vga_b [3:0]"]
    );

    std::this_thread::yield();
  }

  // std::cerr << g_HandleToName[facidx] << " = " << decodeValue((const char* )value) << std::endl;
}

// ---------------------------------------------------------------------

int main(int argc,char **argv)
{
  try {
    if (argc < 2) {
      std::cerr << "Please provide vcd file as argument" << std::endl;
      return -1;
    }

    // std::string infile(argv[1]);
    // g_VCD = AutoPtr<VCDParser>(new VCDParser(infile));

    SimpleUI::init(g_VGA.w(), g_VGA.h(), "Silice Hardware Emulator");

    SimpleUI::onRender = main_render;

    g_Wave = fstReaderOpen(argv[1]);

    struct fstHier* hier = fstReaderIterateHier(g_Wave);
    do {
      switch (hier->htyp) {
      case FST_HT_SCOPE:
        std::cerr << "scope : " << hier->u.scope.name << std::endl;
        break;
      case FST_HT_ATTRBEGIN:
        // std::cerr << "attr  : " << hier->u.attr.name << std::endl;
        break;
      case FST_HT_VAR:
        std::cerr << "signal: " << hier->u.var.name << std::endl;
        g_HandleToName.insert(std::make_pair(hier->u.var.handle, hier->u.var.name));
        break;
      default:
        // std::cerr << "unkonwn" << std::endl;
        break;
      }
      hier = fstReaderIterateHier(g_Wave);
    } while (hier != NULL);

    fstReaderSetFacProcessMaskAll(g_Wave);

    std::thread th([](){
      fstReaderIterBlocks(g_Wave, value_change_callback, NULL, NULL);
    });

    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    glDisable(GL_LIGHTING);

    SimpleUI::loop();

    g_Tex = Tex2DRGBA_Ptr();

    SimpleUI::shutdown();

  } catch (Fatal& f) {
    std::cerr << Console::red << "[fatal] " << f.message() << Console::gray << std::endl;
  }
  return -1;
}

// ---------------------------------------------------------------------

