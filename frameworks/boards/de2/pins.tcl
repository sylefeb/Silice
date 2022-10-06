#============================================================
# Additional settings
#============================================================

set_global_assignment -name ALLOW_ANY_ROM_SIZE_FOR_RECOGNITION ON
set_global_assignment -name ALLOW_ANY_RAM_SIZE_FOR_RECOGNITION ON

#============================================================
# Clocks
#============================================================

set_location_assignment PIN_N2 -to clk
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to clk

#============================================================
# LEDs
#============================================================

set_location_assignment PIN_AE23  -to leds[0]
set_location_assignment PIN_AF23  -to leds[1]
set_location_assignment PIN_AB21  -to leds[2]
set_location_assignment PIN_AC22  -to leds[3]
set_location_assignment PIN_AD22  -to leds[4]
set_location_assignment PIN_AD23  -to leds[5]
set_location_assignment PIN_AD21  -to leds[6]
set_location_assignment PIN_AC21  -to leds[7]
set_location_assignment PIN_AA14  -to leds[8]
set_location_assignment PIN_Y13   -to leds[9]
set_location_assignment PIN_AA13  -to leds[10]
set_location_assignment PIN_AC14  -to leds[11]
set_location_assignment PIN_AD15  -to leds[12]
set_location_assignment PIN_AE15  -to leds[13]
set_location_assignment PIN_AF13  -to leds[14]
set_location_assignment PIN_AE13  -to leds[15]
set_location_assignment PIN_AE12  -to leds[16]
set_location_assignment PIN_AD12  -to leds[17]
set_location_assignment PIN_AE22  -to leds[18]
set_location_assignment PIN_AF22  -to leds[19]
set_location_assignment PIN_W19   -to leds[20]
set_location_assignment PIN_V18   -to leds[21]
set_location_assignment PIN_U18   -to leds[22]
set_location_assignment PIN_U17   -to leds[23]
set_location_assignment PIN_AA20  -to leds[24]
set_location_assignment PIN_Y18   -to leds[25]
set_location_assignment PIN_Y12   -to leds[26]

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to leds*
