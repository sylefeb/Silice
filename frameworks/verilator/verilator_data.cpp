#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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
    fprintf(stdout,"\n[verilator_data] loading %ld bytes from data.raw\n",g_DataSz);
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

void data_write(int wenable,int addr,unsigned char byte)
{
  if (!wenable) {
    return;
  }
  if (addr >= g_DataSz) {
    // record previous
    unsigned char *prev    = g_RawData;
    unsigned long  prev_sz = g_DataSz;
    // allocate new
    g_DataSz  = addr + 1 + 8192 /*take some margin*/;
    g_RawData = new unsigned char[g_DataSz];
    // copy previous
    if (prev != nullptr) {
      memcpy(g_RawData,prev,prev_sz);
      delete [](prev);
    }
  }
  // fprintf(stdout,"[data_write] [%x] = %x\n",addr,byte);
  // store value
  g_RawData[addr] = byte;
}

int  get_random()
{
  return rand() ^ (rand()<<8) ^ (rand()<<16) ^ (rand()<<24);
}

void output_char(int c)
{
  FILE *f = fopen("output.txt","a");
  if (f != NULL) {
    fputc(c,f);
    fclose(f);
  }
}
