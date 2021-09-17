// MIT license, see LICENSE_MIT in Silice repo root
// lcd_ili9351.h currently uses GPL code from Adafruit

$$if not ORANGECRAB and not SIMULATION then
$$error([[this project is specific to the OrangeCrab mounted
$$               on a FeatherWing Keyboard from @solderparty]])
$$end

// ===== screen CONFIGURATION, adjust to your setups
$$screen_width  = 240
$$screen_height = 320

// include SPI controller
$include('../common/spi.ice')

// CPU declaration
riscv cpu_drawer(output uint1  screen_rst,
                 output uint32 screen,
                 output uint1  on_screen,
                 output uint32 leds,
                ) <mem=4096> = compile({

  // =============== firmware in C language ===========================
  #include "lcd_ili9351.h"
  // C main
  void main() {
    screen_init();
    screen_fullscreen();
    int offs = 0;
    while (1) {
      for (int j = 0; j < $screen_height$ ; j ++) {
        for (int i = 0; i < $screen_width$ ; i ++) {
          pix((i + offs)&63,j&63,0);
        }
      }
      ++ offs;
      leds(offs);
    }
  }
  // =============== end of firmware ==================================

})

// now we are creating the hardware hosting the CPU
algorithm main(
  output uint8  leds,
  inout  uint14 G,
  inout  uint6  A,
  output uint1  sck,
  output uint1  sda,
  output uint1  scl,
  output uint1  mosi,
  input  uint1  miso,
) {

  // instantiates our CPU as defined above
  cpu_drawer cpu0;

  // screen driver
  uint1 displ_en         <: cpu0.on_screen;
  uint1 displ_dta_or_cmd <: cpu0.screen[10,1];
  uint8 displ_byte       <: cpu0.screen[0,8];
$$if not SIMULATION then
  spi_mode3_send displ(
    enable          <: displ_en,
    data_or_command <: displ_dta_or_cmd,
    byte            <: displ_byte,
  );
$$end
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

$$end
  }

}
