// MIT license, see LICENSE_MIT in Silice repo root

$$if ICESTICK then
import('../../common/plls/icestick_60.v')
$$end

// include OLED/LCD controller
// expects a 128x128 SSD1351 OLED/LCD screen
$include('../../ice-v/SOCs/ice-v-oled.ice')

riscv cpu_drawer(output uint1  oled_rst,
                 output uint32 oled,
                 output uint1  on_oled,
                ) <mem=4096> = compile({

  // =============== firmware in C language ===========================
  #include "oled_ssd1351.h" // of course we can!
  // C main
  void main() { 
    oled_init();
    oled_fullscreen();
    int offs = 0;
    while (1) {
      for (int j = 0; j < 128 ; j ++) {
        for (int i = 0; i < 128 ; i ++) {
          oled_pix((i + offs)&63,j&63,0);          
        }
      }
      ++ offs;
    }
  }
  // =============== end of firmware ==================================

})

// now we are creating the hardware hosting the CPU
algorithm main(
  output uint8 leds,
  inout  uint8 pmod
$$if ICESTICK then    
  ) <@cpu_clock> {
  // PLL
  uint1 cpu_clock  = uninitialized;
  pll clk_gen (
    clock_in  <: clock,
    clock_out :> cpu_clock
  ); 
$$else
) {
$$end

  // instantiates our CPU as defined above
  cpu_drawer cpu0;
	
  // screen driver
  uint1 displ_en         <: cpu0.on_oled;
  uint1 displ_dta_or_cmd <: cpu0.oled[10,1];
  uint8 displ_byte       <: cpu0.oled[0,8];
$$if not SIMULATION then	
  oled displ(
    enable          <: displ_en,
    data_or_command <: displ_dta_or_cmd,
    byte            <: displ_byte,
  );
$$end
  always {
    leds = cpu0.oled[0,5];

$$if not SIMULATION then	
    // PMOD output
    pmod.oenable = 8b11111111; // all out
    pmod.o = {4b0,displ.oled_din,displ.oled_clk,displ.oled_dc,~cpu0.oled_rst};
$$else
    __display("%b %b %d (%b)",cpu0.on_oled,cpu0.oled[10,1],cpu0.oled[0,8],cpu0.oled_rst);		
$$end
  }
    
}
