
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

// NOTE: this code drives 20 LEDs, change the number below
$$ NUM_PIXS = 20

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
riscv cpu_fun(
  output uint24 clr,
  output uint8  id,
  output uint1  on_id,
  output uint32 leds) <mem=2048> {
  // ====== C firmware ======
  void wait() {
    for (int w = 0; w < 5000 ; ++w) { asm volatile ("nop;"); }
  }
  unsigned int __mulsi3 (unsigned int a, unsigned int b)
  { // from https://raw.githubusercontent.com/gcc-mirror/gcc/master/libgcc/config/epiphany/mulsi3.c
    // function is under GPLv3 license, see link above
    unsigned int r = 0;
    while (a) {
        if (a & 1) { r += b; }
        a >>= 1; b <<= 1;
    }
    return r;
  }
  typedef struct {
    int  r;
    int  g;
    int  b;
    int  dir;
    int  intens;
  } t_rgb;
  t_rgb colors[$NUM_PIXS$];
  void main() {
    leds(0);
    // choose random colors
    int rng  = 31421;
    for (int l = 0; l < $NUM_PIXS$ ; l++) {
      rng = ((rng<<5) ^ 6927) + (rng ^ l);
      rng = ((rng) ^ 31421) + (l);
      colors[l].intens = rng & 63;
      rng = ((rng<<5) ^ 6927) + (rng ^ l);
      rng = ((rng) ^ 31421) + (l);
      colors[l].r = rng & 255;
      rng = ((rng<<5) ^ 6927) + (rng ^ l);
      rng = ((rng) ^ 31421) + (l);
      colors[l].g = rng & 255;
      rng = ((rng<<5) ^ 6927) + (rng ^ l);
      rng = ((rng) ^ 31421) + (l);
      colors[l].b = rng & 255;
      rng = ((rng<<5) ^ 6927) + (rng ^ l);
      rng = ((rng) ^ 31421) + (l);
      colors[l].dir = rng < 0 ? -1 : 1;
    }
    while (1) {
      for (int l = 0;  l < $NUM_PIXS$ ; l++) {
        int i = colors[l].intens;
        int r = ((colors[l].r * i) >> 8);
        int g = ((colors[l].g * i) >> 8);
        int b = ((colors[l].b * i) >> 8);
        clr( r | (g<<8) | (b<<16) );
        id ( l );
        colors[l].intens += colors[l].dir;
        if (colors[l].intens < 0) {
          colors[l].intens = 0; colors[l].dir = -colors[l].dir;
        } else if (colors[l].intens > 64) {
          colors[l].intens = 64; colors[l].dir = -colors[l].dir;
        }
      }
      wait();
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
  simple_dualport_bram uint24 colors[$NUM_PIXS$] = {pad(0)};

  always_after {
    leds            = cpu0.leds[16,5];
    pmod.oenable    = 8b11111111;
    pmod.o          = {8{ctrl}}; // output on PMOD pins
    colors.wdata1   = cpu0.clr;
    colors.addr1    = cpu0.id;
    colors.wenable1 = cpu0.on_id;
  }

  // We take it easy (#FPGAFriday) and use Silice FSM capability
  // to implement the NeoPixel driver (single LED, just getting started)
  while (1) {
    // iterate through the LEDs and set their color
    uint5 led_id = 0;
    colors.addr0 = led_id;
    while (led_id != $NUM_PIXS$) {
      uint5 i      = 0;
      // color to be sent
      send_clr     = colors.rdata0;
      // next LED
      led_id       = led_id + 1;
      colors.addr0 = led_id;
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
    }
    // send reset
    ctrl = 0;
    cnt  = 0;
    while (cnt != $res_cycles$) {
      cnt  = cnt + 1;
    }
  }

}
