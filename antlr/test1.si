
riscv cpu_blinky(output uint32 leds) <mem=512> = compile({
  // =============== firmware in C language ===============

  void next(int *v) { ++(*v); }

  void wait() { for (volatile int w = 0 ; w < 1000000 ; ++w) {} }

  void main() {
    int i = 0;
    while (1) {
      leds(i);
      wait();
      inc(&i);
    }
  }
  
  // =============== end of firmware ===================== 
})

algorithm main(output uint8 leds)
{
  cpu_blinky cpu0;
  leds   := cpu0.leds;
}
