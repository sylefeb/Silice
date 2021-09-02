
riscv cpu_blinky(output uint32 leds) <mem=1024> = compile({
  // =============== firmware in C language ===============
  // goes to next (just to show off this is indeed C)
  //void next(int *v) { ++(*v); }
  // wait for a while
$$if SIMULATION then  
  //void wait() { for (int w = 0 ; w < 10 ; ++w) {  asm volatile ("nop;"); } }
$$else  
  //void wait() { for (int w = 0 ; w < 10000 ; ++w) {  asm volatile ("nop;"); } }
$$end
  // C main
  void main() { 
  /*
    int i = 0;
    while (1) {
      leds(i);
      wait();
      next(&i);
    }
   */
   leds(4);
  }
  // =============== end of firmware ===================== 
})

algorithm main(output uint8 leds)
{
  uint32 iter(0);
  cpu_blinky cpu0;
  leds   := cpu0.leds;
$$if SIMULATION then  
  while (iter != 1000) { iter = iter + 1; }
$$else
  while (1) { }
$$end  
}
