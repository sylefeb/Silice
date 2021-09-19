// MIT license, see LICENSE_MIT in Silice repo root

$$if not ORANGECRAB and not SIMULATION then
$$error([[this project is specific to the OrangeCrab mounted
$$               on a FeatherWing Keyboard from @solderparty]])
$$end

// ===== screen CONFIGURATION, adjust to your setups
$$screen_width  = 240
$$screen_height = 320

// include SPI controller
$include('../common/spi.ice')

// PLL
import('../common/plls/orangecrab_100.v')

// CPU declaration
riscv cpu_drawer(output uint1  screen_rst,
                 output uint32 screen,
                 output uint32 rgb,
                 output uint1  on_rgb,
                 output uint1  on_screen,
                 output uint32 leds,
                 output uint1  on_leds
                ) <
                  mem=65536,
                  ICEV_FAST_SHIFT=1,
                  O=3
                > = compile({

  // =============== firmware in C language ===========================
  #include "lcd_ili9351.h"

  unsigned char tbl[256*240 + 8/*padding*/]; // doom fire 'framebuffer'

  unsigned char pal[] = {     //_ 32 RGB entries (a 'fire' palette)
    0x04,0x04,0x04, 0x1c,0x04,0x04, 0x2c,0x0c,0x04, 0x44,0x0c,0x04,
    0x54,0x14,0x04, 0x64,0x1c,0x04, 0x74,0x1c,0x04, 0x9c,0x2c,0x04,
    0xac,0x3c,0x04, 0xbc,0x44,0x04, 0xc4,0x44,0x04, 0xdc,0x54,0x04,
    0xdc,0x54,0x04, 0xd4,0x5c,0x04, 0xd4,0x5c,0x04, 0xd4,0x64,0x0c,
    0xcc,0x74,0x0c, 0xcc,0x7c,0x0c, 0xcc,0x84,0x14, 0xc4,0x84,0x14,
    0xc4,0x94,0x1c, 0xbc,0x9c,0x1c, 0xbc,0x9c,0x1c, 0xbc,0xa4,0x24,
    0xbc,0xa4,0x24, 0xbc,0xac,0x2c, 0xb4,0xac,0x2c, 0xb4,0xb4,0x2c,
    0xcc,0xcc,0x6c, 0xdc,0xdc,0x9c, 0xec,0xec,0xc4, 0xfc,0xfc,0xfc};

  void draw_fire() // draws fire onto the LCD
  {
    leds(2);
    for (int u=0;u<256;u++) {
      unsigned char *col = tbl + u;
      for (int v=0;v<240;v++) {
        // int clr  = (tbl[u + (v<<8)]>>2) & 31;
        int clr  = ((*col)>>2)&31;
        col     += 256;
        int clr3 = (clr<<1)+clr; // x3 (RGB)
        unsigned char *ptr = pal + clr3;
        pix(*ptr++,*ptr++,*ptr++);
        // rgb(*ptr);
      }
    }
    leds(3);
  }

  int rng  = 31421;  // random number generator seed

  void update_fire() // update the fire framebuffer
  {
    leds(0);
    // move up
    unsigned char *below   = tbl;
    unsigned char *current = tbl + 256;
    for (int v=256;v<240*256;v++) {
      int clr = 0;
      if ((*below) > 1) {
        clr = (*below)-(rng&1);
      }
      rng = ((rng<<5) ^ 6927) + ((rng>>5) ^ v);
      *(current + (rng&3)) = clr; // NOTE: there padding to the table
                                  // to avoid out of bounds access
      ++ below;
      ++ current;
    }
    leds(1);
  }

  // C main
  void main() {

    screen_init();
    screen_rect(0,240, 32,288);

    for (int v=0;v<240;v++) {
      for (int u=0;u<256;u++) {
        tbl[u+(v<<8)] = (v == 0) ? 127 : 0;
      }
    }

    int time = 0;
    while (1) {
      draw_fire();
      update_fire();
      ++ time;
      if ((time&127) == 0) {
        // turn off
        for (int u=0;u<256;u++) {
          tbl[u] = 0;
        }
      }
      if ((time&127) == 63) {
        // turn on
        for (int u=0;u<256;u++) {
          tbl[u] = 127;
        }
      }
    }
  }

  // =============== end of firmware ==================================
})

// now we are creating the hardware hosting the CPU
algorithm main(
  output uint8  leds,
$$if SIMULATION then
) {
$$else
  inout  uint14 G,
  inout  uint6  A,
  output uint1  sck,
  output uint1  sda,
  output uint1  scl,
  output uint1  mosi,
  input  uint1  miso,
// PLL
) <@fast_clock> {
  uint1 fast_clock(0);
  pll main_pll(
    clkin   <: clock,
    clkout0 :> fast_clock
  );
$$end
  // instantiates our CPU as defined above
  cpu_drawer cpu0;

$$if SIMULATION then
  uint32 cycle(0);
  uint32 prev(0);
$$end

  // screen driver
  uint1 displ_en         <: cpu0.on_screen;
  uint1 displ_dta_or_cmd <: cpu0.screen[10,1];
  uint8 displ_byte       <: cpu0.screen[0,8];
  spi_mode3_send displ(
    enable          <: displ_en,
    data_or_command <: displ_dta_or_cmd,
    byte            <: displ_byte,
  );

  always {
    leds      = cpu0.leds;
$$if not SIMULATION then
    G.oenable = 14b11111111111111;
    G.o       = {
      /*13:        */ 1b0,
      /*12:        */ 1b0,
      /*11:        */ 1b0,
      /*10:  lcd_dc*/ displ.spi_dc,
      /* 9:  lcd_cs*/ 1b0,
      /* 8:        */ 1b0,
      /* 7:        */ 1b0,
      /* 6: stmp_cs*/ 1b1,
      /* 5: card_cs*/ 1b1,
      /* 4:        */ 1b0,
      /* 3:        */ 1b0,
      /* 2:        */ 1b0,
      /* 1:        */ 1b0,
      /* 0:        */ 1b0
    };
    A.oenable = 6b111111;
    A.o       = {5b0,cpu0.screen_rst};
    mosi      = displ.spi_mosi;
    sck       = displ.spi_clk;
$$else
    if (cpu0.on_leds) {
      __display("%d] elapsed: %d cycles",cpu0.leds,cycle - prev);
      prev = cycle;
    }
    cycle     = cycle + 1;
$$end
  }

}
