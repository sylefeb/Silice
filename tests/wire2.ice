algorithm main() {
  uint8 a = 1;
  uint8 b = 2;
  uint8 c = 3;
  uint8 d = 4;
  
  uint8 z        := a + d;
  uint8 w        := a;
  uint9 a_plus_b := w + b;
  
  a = 3;
  b = 5;
  d = 1;
++:
  c = a_plus_b;
  
}
