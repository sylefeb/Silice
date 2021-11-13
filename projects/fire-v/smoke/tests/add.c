// MIT license, see LICENSE_MIT in Silice repo root
// @sylefeb 2020
// https://github.com/sylefeb/Silice

int f(int v) {
  return v + 10;
}

void main()
{
  for (int i = 0; i < 10 ; i ++) {
    *(int*)0x20000000 = i;
  }
}
