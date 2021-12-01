// this project is meant for the icestick, but could be adapted by simply
// using an adapted PLL
$$if not ICESTICK and not ICEBREAKER then
$$ error("this project is meant for the icestick or icebreaker")
$$end

$$if ICESTICK then
import('../../common/plls/icestick_25.v')
$$end
$$if ICEBREAKER then
import('../../common/plls/icebrkr_25.v')
$$end

// include UART
$$uart_in_clock_freq_mhz = 25
$include('../../projects/common/uart.ice')

// instantiate a RISC-V RV32I processor
//               vvvvvvvvvvvvvvvvvv our CPU outputs one uint32 value
riscv cpu(output uint32 uart,output uint1 on_uart)
                                      <mem=4096,
                                      core="ice-v-dual",
                                      stack=32
                                     > {
  // =============== firmware in C language ===========================
  unsigned char tbl[32*32]={
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  };

  unsigned char *pal[] = {
    "4","4","4",
    "28","4","4",
    "44","12","4",
    "68","12","4",
    "84","20","4",
    "100","28","4",
    "116","28","4",
    "156","44","4",
    "172","60","4",
    "188","68","4",
    "196","68","4",
    "220","84","4",
    "220","84","4",
    "212","92","4",
    "212","92","4",
    "212","100","12",
    "204","116","12",
    "204","124","12",
    "204","132","20",
    "196","132","20",
    "196","148","28",
    "188","156","28",
    "188","156","28",
    "188","164","36",
    "188","164","36",
    "188","172","44",
    "180","172","44",
    "180","180","44",
    "204","204","108",
    "220","220","156",
    "236","236","196",
    "252","252","252"};

  int rng  = 31421;

  void update_fire()
  {
    // move up
    for (int v=1;v<32;v++) {
      for (int u=0;u<32;u++) {
        int below = tbl[(u) + ((v-1)<<5)];
        int clr   = 0;
        if (below > 3) {
          clr = below-1-(rng&3);
        } else if (below > 1) {
          clr = below-(rng&1);
        }
        rng = ((rng<<5) ^ 6927) + ((rng>>5) ^ u);
        tbl[((u+(rng&3))&31) + (v<<5)] = clr;
      }
    }
  }

  void core0_main()
  {
    for (int v=0;v<32;v++) {
      for (int u=0;u<32;u++) {
        tbl[u+(v<<5)] = (v == 0) ? 63 : 0;
      }
    }
    int time = 0;
    while (1) {
      update_fire();
      ++ time;
    }
  }

  static inline int time()
  {
    int cycles;
    asm volatile ("rdcycle %0" : "=r"(cycles));
    return cycles;
  }

  static inline void pause(int cycles)
  {
    long tm_start = time();
    while (time() - tm_start < cycles) { }
  }

  void putchar(int c)
  {
    uart(c);
    pause(5000);
  }

  static inline void print_string(const char* s)
  {
    for (const char* p = s; *p; ++p) {
        putchar(*p);
    }
  }

  #include <stdarg.h>

  static inline int printf(const char *fmt,...)
  {
    va_list ap;
    for (va_start(ap, fmt);*fmt;fmt++) {
      if (*fmt=='%') {
        fmt++;
        if (*fmt=='s')      print_string(va_arg(ap,char *));
        else                putchar(*fmt);
      } else {
        putchar(*fmt);
      }
    }
    va_end(ap);
  }

  void core1_main()
  {
    // send fire framebuffer to UART
    while (1) {
      printf("\\033[H");
      for (int v=31;v>=0;--v) {
        for (int u=0;u<32;++u) {
          int clr  = tbl[u + (v<<5)]>>1;
          // int clr3 = (clr<<1)+clr;
          // unsigned char **ptr = pal + clr3;
          // printf("\\033[48;2;%s;%s;%sm ",ptr[0],ptr[1],ptr[2]);
          putchar(" _.:-=+ox*X#%@8BG"[(clr>>1) & 15]);
        }
        printf("\\n\\r");
      }
    }
//    while (1) {
//      printf("\\033[48;2;0;255;0mHello world\\n");
//    }
  }

  // C main
  void main() {
    if (core_id() == 0) { core0_main(); } else { core1_main(); }
  }
  // =============== end of firmware ==================================
}

// now we are creating the hardware hosting the CPU
algorithm main(
  output uint8 leds,
$$if UART then
  output uint1 uart_tx,
  input  uint1 uart_rx,
$$end
) <@fast_clock> {

  uint1 fast_clock = uninitialized;
  pll clk_gen (
    clock_in  <: clock,
    clock_out :> fast_clock
  );

  cpu cpu0;

  uart_out uo;
$$if UART then
  uart_sender usend<reginputs>(
    io      <:> uo,
    uart_tx :>  uart_tx
  );
$$end

$$if SIMULATION then
  uint32 iter(0);
$$end

  always {
    uo.data_in_ready = cpu0.on_uart; // when uart pulses, send
    uo.data_in       = cpu0.uart;    // track value to be sent

    leds             = cpu0.uart; // for debugging

$$if SIMULATION then
    if (iter == 256) { __finish(); }
    iter = iter + 1;
$$end
  }

}
