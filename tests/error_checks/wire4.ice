algorithm main() {
  uint8 a = 1;
  uint8 b = 2;
  uint8 w        := a;
  uint9 a_plus_b ::= w + b;
  
  a = 3;
  b = 5;
++:
  a = a_plus_b;
  
}
