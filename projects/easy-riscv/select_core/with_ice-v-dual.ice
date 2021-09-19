
// instantiate a RISC-V RV32I processor
//               vvvvvvvvvvvvvvvvvv our CPU outputs one uint32 value
riscv cpu_blinky(output uint32 leds) <mem=1024,
//                                    ^^^^^^^ memory size in bytes
                                      core="ice-v-dual",
//                                    ^^^^^^^ choice of core
                                      stack=32
//                                    ^^^^^^^ stack size in bytes (required by core)
                                     > {
  // =============== firmware in C language ===========================
  // cpu0 main
  void cpu0_main() {
    int i = 0;
    while (1) { // until the end of times
      leds(--i);
    }
  }
  // cpu1 main
  void cpu1_main() {
    int i = 0;
    while (1) { // until the end of times
      leds(++i);
    }
  }
  // C main
  void main() {
    if (cpu_id() == 0) { cpu0_main(); } else { cpu1_main(); }
  }

  // =============== end of firmware ==================================
  // ==================================================================
}

// now we are creating the hardware hosting the CPU
algorithm main(output uint8 leds)
{
  cpu_blinky cpu0;    // instantiates our CPU as defined above

  always {
    leds = cpu0.leds;	// sets the hardware LEDs to the CPU output
  }

$$if SIMULATION then
  // run only 256 cycles in simulation
  {
    uint32 iter(0);
    while (iter != 256) { __display("[cycle %d] leds %d",iter,leds);
                         iter = iter + 1; }
  }
$$else
  // run forever in hardware
  while (1) { }
$$end
}
