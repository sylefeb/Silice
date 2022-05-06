#include <stdio.h>
#include <stdlib.h>

static unsigned long  g_DataSz  = 0;
static unsigned char *g_RawData = nullptr;

int data(int addr)
{
  if (g_RawData == nullptr) {
    // on first call load file into a memory array
    FILE *f = fopen("../data.raw","rb");
    if (f == NULL) {
      fprintf(stdout,"\n[verilator_data] file data.raw not found\n");
      exit (-1);
      return 0;
    }
    fseek(f, 0, SEEK_END);
    g_DataSz = ftell(f);
    fprintf(stdout,"\n[verilator_data] loading %d bytes from data.raw\n",g_DataSz);
    fseek(f, 0, SEEK_SET);
    g_RawData = new unsigned char[g_DataSz];
    fread(g_RawData,sizeof(unsigned char),g_DataSz,f);
    fclose(f);
  }
  if (addr < g_DataSz) {
    return g_RawData[addr];
  } else {
    return 0;
  }
}
