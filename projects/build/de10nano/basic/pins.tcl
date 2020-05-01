set_location_assignment PIN_W15  -to LED0
set_location_assignment PIN_AA24 -to LED1
set_location_assignment PIN_V16  -to LED2
set_location_assignment PIN_V15  -to LED3
set_location_assignment PIN_AF26 -to LED4
set_location_assignment PIN_AE26 -to LED5
set_location_assignment PIN_Y16  -to LED6
set_location_assignment PIN_AA23 -to LED7

set_location_assignment PIN_V11  -to clk

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_*
set_instance_assignment -name CURRENT_STRENGTH_NEW "MAXIMUM CURRENT" -to SDRAM_*
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to SDRAM_*
set_instance_assignment -name FAST_OUTPUT_ENABLE_REGISTER ON -to SDRAM_DQ[*]
set_instance_assignment -name FAST_INPUT_REGISTER ON -to SDRAM_DQ[*]
set_instance_assignment -name ALLOW_SYNCH_CTRL_USAGE OFF -to *|SDRAM_*
