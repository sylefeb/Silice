
// instantiate a RISC-V RV32I processor ; yup, that is that easy!
//               vvvvvvvvvvvvvvvvvv our CPU outputs one uint32 value
riscv cpu_blinky(output uint32 leds) <mem=256> = compile({

  // =============== firmware in C language ===========================
	// The code below is actual C-code, not Silice code
	// this code gets compiled with RISC-V gcc qnd used by the CPU
	// ==================================================================
	
  // C-function, goes to next value (just to show off a C pointer)
  void next(int *v) { ++(*v); }
  // C-function, wait for a while
$$if SIMULATION then  -- even C-code can be changed by the Silice pre-processor!
  // in simulation we wait only a short time
  void wait() { for (int w = 0 ; w < 10 ; ++w)     { asm volatile ("nop;"); } }
$$else  
  // on actual hardware we wait much longer
  void wait() { for (int w = 0 ; w < 100000 ; ++w) { asm volatile ("nop;"); } }
$$end
  // C main
  void main() { 
    int i = 0;
    while (1) { // until the end of times

      leds(i);  // output to leds
                // => this goes straight out of the CPU into our hardware

      wait();   // wait
      next(&i); // next value
    }
  }
	
  // =============== end of firmware ==================================
	// ==================================================================
})

// now we are creating the hardware hosting the CPU
algorithm main(output uint8 leds)
{
  cpu_blinky cpu0;    // instantiates our CPU as defined above

  always {
    leds = cpu0.leds;	// sets the hardware LEDs to the CPU output
  }
  
$$if SIMULATION then  
  // run only 1000 cycles in simulation
  uint32 iter(0);
  while (iter != 1000) { iter = iter + 1; }
$$else
  // run forever in hardware
  while (1) { }
$$end  
}
