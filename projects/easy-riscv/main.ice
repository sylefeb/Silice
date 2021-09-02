
riscv cpu_blinky(output uint32 leds) <mem=512> = compile({
  // =============== firmware in C language ===============
  // goes to next (just to show off this is indeed C)
  void next(int *v) { ++(*v); }
  // wait for a while
  void wait() { for (int w = 0 ; w < 16 ; ++w) {  asm volatile ("nop;"); } }
  // C main
  void main() { 
    int i = 0;
    while (1) {
      leds(i);
      wait();
      next(&i);
    }
  }
  // =============== end of firmware ===================== 
})

algorithm main(output uint8 leds)
{
  uint32 iter(0);
  cpu_blinky cpu0;
  leds   := cpu0.leds;
  while (iter != 2048) { iter = iter + 1; }
}
