algorithm main() {
  uint8 a = 1;
  uint8 b = 2;
  uint9 a_plus_b ::= a + b;
  
  a = 15;
  b = 3;
  
  __display("%d", a_plus_b);
}