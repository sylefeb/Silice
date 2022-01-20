
$$if not ICESTICK and not SIMULATION then
$$ error("This is assuming the 12 MHz clock of the IceStick, please adjust")
$$end

// WS2812B timings
// see https://cdn-shop.adafruit.com/datasheets/WS2812B.pdf
// T0H  0.4us
// T0L  0.85us
// T1H  0.8us
// T1L  0.45us
// RES 55.0us

$$ t0h_cycles          = 5  -- 416 nsec
$$ t0l_cycles          = 10 -- 833 nsec
$$ t1h_cycles          = 10 -- 833 nsec
$$ t1l_cycles          = 5  -- 416 nsec
$$ res_cycles          = 800
$$ print('t0h_cycles = ' .. t0h_cycles)
$$ print('t0l_cycles = ' .. t0l_cycles)
$$ print('t1h_cycles = ' .. t1h_cycles)
$$ print('t1l_cycles = ' .. t1l_cycles)
$$ print('res_cycles = ' .. res_cycles)

// A Risc-V CPU generating the color pattern
riscv cpu_fun(output uint24 clr,output uint32 leds) <mem=1024> {
  // ====== C firmware ======
  int l;
  void wait() {
    for (int w = 0; w < 5000 ; ++w) { leds(++l); asm volatile ("nop;"); }
  }
  void pulse(int shift) {
    for (int i = 0; i <= 255 ; ++i) {  // 0 => 255
      clr(i<<shift);
      wait();
    }
    for (int i = 255; i >= 0 ; --i) { // 255 => 0
      clr(i<<shift);
      wait();
    }
  }
  void main() {
    l = 0;
    while (1) {
      // pulse red
      pulse(8);
      // pulse green
      pulse(16);
      // pulse blue
      pulse(0);
    }
  }
  // =========================
}

// The hardware implements the LED driver
algorithm main(output uint8 leds,inout uint8 pmod)
{
  cpu_fun cpu0;   // instantiates our CPU

  uint10 cnt(0);  // counter for generating the control signal
  uint1  ctrl(0); // control signal state

  uint24 send_clr(0);

  always_after {
    leds         = cpu0.leds[16,5];
    pmod.oenable = 8b11111111;
    pmod.o       = {8{ctrl}}; // output on PMOD pins
    // __display("%b",leds);
  }

  // We take it easy (#FPGAFriday) and use Silice FSM capability
  // to implement the NeoPixel driver (single LED, just getting started)
  while (1) {
    uint5 i  = 0;
    // pull color from CPU
    send_clr = cpu0.clr;
    // send the 24 bits
    while (i != 24) {

      uint10 th <:: send_clr[23,1] ? $t1h_cycles-2$ : $t0h_cycles-2$;
      //                                        ^^^              ^^^
      // this accounts for the two cycles entering and exiting a while
      uint10 tl <:: send_clr[23,1] ? $t1l_cycles-3$ : $t0l_cycles-3$;
      //                                        ^^^              ^^^
      // this accounts for the two cycles entering and exiting a while and
      // the additional cycle it takes to loop back in the main loop

      // generates a '1'
      ctrl = 1;
      cnt  = 0;
      while (cnt != th) {
        cnt  = cnt + 1;
      }

      // generates a '0'
      ctrl = 0;
      cnt  = 0;
      while (cnt != tl) {
        cnt  = cnt + 1;
      }

      // shift clr to send next bit
      send_clr = send_clr << 1;
      // count sent bits
      i        = i + 1;
    }
    // send reset
    ctrl = 0;
    cnt  = 0;
    while (cnt != $res_cycles$) {
      cnt  = cnt + 1;
    }
  }

}
