
// riscv cpu_test(input uint32 a,output uint32 b) = compile(file("firmware.c"))

riscv cpu_test(input uint32 a,output uint32 b) = compile({ 

  #include "stdlib.h"

  int f(int v) 
  {
    return v+1;
  }

  void main() { 
    b(f(a()));
  }

 })

algorithm main(output uint8 leds)
{

}
