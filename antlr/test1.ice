algorithm main(output int8 led)
{
  int8 a = 0;
  int8 b = 1;
  int8 c = 2;

  int6  e = 6b111000;
  int2  f = 2b10;
  int10 g = 0;
  
  g := {b,a,2b11};

  if (a === b) {    
  } else { if (a == b) {    
  } }

  if (a !== b) {    
  } else { if (a != b) {    
  } }

  b = !b ;
  c = a ~ b;
  c = a ^ b;
  c = a ^~ b;
  c = a ~^ b;
  c = ~ b; 
  c = a ~ ~ b;

  if (a && b || c) {  
  }

  c = a & 3;
  
  a = &a;
  a = |a;
  a = ~|a;
  a = ~&a;
  a = ~^a;
  a = ^~a;
  
  b = b << 2;
  b = b <<< 3;
  b = b >> 2;
  b = b >>> 3;
  
  a = {1b1,3b101,2hFF} + 53;
}
