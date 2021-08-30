
riscv cpu_test(input uint32 a,output uint32 b) = compile({

  #include "stdlib.h"

  int f(int val) 
  {
    return val + 1;
  }

  void main() { 
    b(f(a()));
  }
  
})

algorithm main(output uint8 leds)
{

}
