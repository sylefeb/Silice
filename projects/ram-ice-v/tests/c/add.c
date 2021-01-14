
int f(int v) {
  return v + 10;
}

void main() 
{
  for (int i = 0; i < 10 ; i ++) {
    *(int*)0x20000000 = i;
  }
}
