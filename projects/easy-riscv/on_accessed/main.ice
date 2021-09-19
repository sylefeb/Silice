
riscv cpu_test(
    output uint32 v,
    output uint1  on_v, // This will be pulsed whenever v is accessed by the CPU
    //     ^^^^^  ^^
    //     |      |
    //     |      on_ prefix
    //     single bit
    //  These conditions are required for Silice to construct the on_v output
    input  uint32 i,
    output uint1  on_i,
    )
<mem=256> {
  // =============== firmware in C language ===========================
  // C-function, wait for a while
$$if SIMULATION then  -- even C-code can be changed by the Silice pre-processor!
  // in simulation we do not wait
  void wait() {  }
$$else
  // on actual hardware we wait much longer
  void wait() { for (int w = 0 ; w < 100000 ; ++w) { asm volatile ("nop;"); } }
$$end
  // C main
  void main() {
    while (1) { // until the end of times
      v(i());     // write to v, on_v will be pulsed
      wait();   // wait some
    }
  }
  // =============== end of firmware ==================================
}

// now we are creating the hardware hosting the CPU
algorithm main(output uint8 leds)
{
  cpu_test cpu0;      // instantiates our CPU as defined above
  uint5    cnt(0);    // counts accesses to v

  always {
    leds = cnt;
    // increment cnt on a pulse to on_v or on_i
    cnt  = (cpu0.on_v|cpu0.on_i) ? cnt + 1 : cnt;
  }

$$if SIMULATION then
  // run only 256 cycles in simulation
  {
    uint32 iter(0);
    while (iter != 256) { __display("[cycle %d] leds:%d on_v:%b on_i:%b",
                                     iter,leds,cpu0.on_v,cpu0.on_i);
                         iter = iter + 1; }
  }
$$else
  // run forever in hardware
  while (1) { }
$$end
}
