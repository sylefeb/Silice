#include <stdio.h>
#include <stdlib.h>

int data(int addr)
{
  FILE *f = fopen("../data.raw","rb");
  if (f == NULL) {
    fprintf(stdout,"\n[verilator_data] file data.raw not found\n");
    exit (-1);
    return 0;
  }
  fseek(f, addr,SEEK_SET);
  int v = 0;
  fread(&v,1,sizeof(int),f);
  fclose(f);
  // fprintf(stdout,"\n[verilator_data] [%d] = %d\n",addr,v&255);
  return v;
}
