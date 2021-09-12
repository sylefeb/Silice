// MIT license, see LICENSE_MIT in Silice repo root

int f(int v) {
  return v + 10;
}

void main() 
{
  for (int i = 0; i < 10 ; i ++) {
    *(int*)0x20000000 = i;
  }
}
