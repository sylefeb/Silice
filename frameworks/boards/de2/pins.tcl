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

#============================================================
# SDRAM
#============================================================

set_location_assignment PIN_T6 -to SDRAM_A[0]
set_location_assignment PIN_V4 -to SDRAM_A[1]
set_location_assignment PIN_V3 -to SDRAM_A[2]
set_location_assignment PIN_W2 -to SDRAM_A[3]
set_location_assignment PIN_W1 -to SDRAM_A[4]
set_location_assignment PIN_U6 -to SDRAM_A[5]
set_location_assignment PIN_U7 -to SDRAM_A[6]
set_location_assignment PIN_U5 -to SDRAM_A[7]
set_location_assignment PIN_W4 -to SDRAM_A[8]
set_location_assignment PIN_W3 -to SDRAM_A[9]
set_location_assignment PIN_Y1 -to SDRAM_A[10]
set_location_assignment PIN_V5 -to SDRAM_A[11]

set_location_assignment PIN_AE2 -to SDRAM_BA[0]
set_location_assignment PIN_AE3 -to SDRAM_BA[1]

set_location_assignment PIN_V6 -to SDRAM_DQ[0]
set_location_assignment PIN_AA2 -to SDRAM_DQ[1]
set_location_assignment PIN_AA1 -to SDRAM_DQ[2]
set_location_assignment PIN_Y3 -to SDRAM_DQ[3]
set_location_assignment PIN_Y4 -to SDRAM_DQ[4]
set_location_assignment PIN_R8 -to SDRAM_DQ[5]
set_location_assignment PIN_T8 -to SDRAM_DQ[6]
set_location_assignment PIN_V7 -to SDRAM_DQ[7]
set_location_assignment PIN_W6 -to SDRAM_DQ[8]
set_location_assignment PIN_AB2 -to SDRAM_DQ[9]
set_location_assignment PIN_AB1 -to SDRAM_DQ[10]
set_location_assignment PIN_AA4 -to SDRAM_DQ[11]
set_location_assignment PIN_AA3 -to SDRAM_DQ[12]
set_location_assignment PIN_AC2 -to SDRAM_DQ[13]
set_location_assignment PIN_AC1 -to SDRAM_DQ[14]
set_location_assignment PIN_AA5 -to SDRAM_DQ[15]

set_location_assignment PIN_AD2 -to SDRAM_DQML
set_location_assignment PIN_Y5 -to SDRAM_DQMH
set_location_assignment PIN_AA7 -to SDRAM_CLK
set_location_assignment PIN_AA6 -to SDRAM_CKE
set_location_assignment PIN_AD3 -to SDRAM_nWE
set_location_assignment PIN_AB3 -to SDRAM_nCAS
set_location_assignment PIN_AC3 -to SDRAM_nCS
set_location_assignment PIN_AB4 -to SDRAM_nRAS

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_*
set_instance_assignment -name CURRENT_STRENGTH_NEW "MAXIMUM CURRENT" -to SDRAM_*
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to SDRAM_*
set_instance_assignment -name FAST_OUTPUT_ENABLE_REGISTER ON -to SDRAM_DQ[*]
set_instance_assignment -name FAST_INPUT_REGISTER ON -to SDRAM_DQ[*]
set_instance_assignment -name ALLOW_SYNCH_CTRL_USAGE OFF -to *|SDRAM_*
set_instance_assignment -name FAST_OUTPUT_ENABLE_REGISTER ON -to SDRAM_DQML
set_instance_assignment -name FAST_OUTPUT_ENABLE_REGISTER ON -to SDRAM_DQMH

#============================================================
# VGA
#============================================================

set_location_assignment PIN_C8  -to vga_r[0]
set_location_assignment PIN_F10 -to vga_r[1]
set_location_assignment PIN_G10 -to vga_r[2]
set_location_assignment PIN_D9  -to vga_r[3]
set_location_assignment PIN_C9  -to vga_r[4]
set_location_assignment PIN_A8  -to vga_r[5]
set_location_assignment PIN_H11 -to vga_r[6]
set_location_assignment PIN_H12 -to vga_r[7]
set_location_assignment PIN_F11 -to vga_r[8]
set_location_assignment PIN_E10 -to vga_r[9]

set_location_assignment PIN_B9  -to vga_g[0]
set_location_assignment PIN_A9  -to vga_g[1]
set_location_assignment PIN_C10 -to vga_g[2]
set_location_assignment PIN_D10 -to vga_g[3]
set_location_assignment PIN_B10 -to vga_g[4]
set_location_assignment PIN_A10 -to vga_g[5]
set_location_assignment PIN_G11 -to vga_g[6]
set_location_assignment PIN_D11 -to vga_g[7]
set_location_assignment PIN_E12 -to vga_g[8]
set_location_assignment PIN_D12 -to vga_g[9]

set_location_assignment PIN_J13 -to vga_b[0]
set_location_assignment PIN_J14 -to vga_b[1]
set_location_assignment PIN_F12 -to vga_b[2]
set_location_assignment PIN_G12 -to vga_b[3]
set_location_assignment PIN_J10 -to vga_b[4]
set_location_assignment PIN_J11 -to vga_b[5]
set_location_assignment PIN_C11 -to vga_b[6]
set_location_assignment PIN_B11 -to vga_b[7]
set_location_assignment PIN_C12 -to vga_b[8]
set_location_assignment PIN_B12 -to vga_b[9]

set_location_assignment PIN_B8  -to vga_clock

set_location_assignment PIN_D6  -to vga_blank
set_location_assignment PIN_A7  -to vga_hs
set_location_assignment PIN_D8  -to vga_vs
set_location_assignment PIN_B7  -to vga_sync

#============================================================
# Buttons
#============================================================

set_location_assignment PIN_G26  -to btns[0]
set_location_assignment PIN_N23  -to btns[1]
set_location_assignment PIN_P23  -to btns[2]
set_location_assignment PIN_W26  -to btns[3]

#============================================================
# 7-segments displays
#============================================================

set_location_assignment  PIN_AF10 -to hex0[0]
set_location_assignment  PIN_AB12 -to hex0[1]
set_location_assignment  PIN_AC12 -to hex0[2]
set_location_assignment  PIN_AD11 -to hex0[3]
set_location_assignment  PIN_AE11 -to hex0[4]
set_location_assignment  PIN_V14  -to hex0[5]
set_location_assignment  PIN_V13  -to hex0[6]
set_location_assignment  PIN_V20  -to hex1[0]
set_location_assignment  PIN_V21  -to hex1[1]
set_location_assignment  PIN_W21  -to hex1[2]
set_location_assignment  PIN_Y22  -to hex1[3]
set_location_assignment  PIN_AA24 -to hex1[4]
set_location_assignment  PIN_AA23 -to hex1[5]
set_location_assignment  PIN_AB24 -to hex1[6]
set_location_assignment  PIN_AB23 -to hex2[0]
set_location_assignment  PIN_V22  -to hex2[1]
set_location_assignment  PIN_AC25 -to hex2[2]
set_location_assignment  PIN_AC26 -to hex2[3]
set_location_assignment  PIN_AB26 -to hex2[4]
set_location_assignment  PIN_AB25 -to hex2[5]
set_location_assignment  PIN_Y24  -to hex2[6]
set_location_assignment  PIN_Y23  -to hex3[0]
set_location_assignment  PIN_AA25 -to hex3[1]
set_location_assignment  PIN_AA26 -to hex3[2]
set_location_assignment  PIN_Y26  -to hex3[3]
set_location_assignment  PIN_Y25  -to hex3[4]
set_location_assignment  PIN_U22  -to hex3[5]
set_location_assignment  PIN_W24  -to hex3[6]
set_location_assignment  PIN_U9   -to hex4[0]
set_location_assignment  PIN_U1   -to hex4[1]
set_location_assignment  PIN_U2   -to hex4[2]
set_location_assignment  PIN_T4   -to hex4[3]
set_location_assignment  PIN_R7   -to hex4[4]
set_location_assignment  PIN_R6   -to hex4[5]
set_location_assignment  PIN_T3   -to hex4[6]
set_location_assignment  PIN_T2   -to hex5[0]
set_location_assignment  PIN_P6   -to hex5[1]
set_location_assignment  PIN_P7   -to hex5[2]
set_location_assignment  PIN_T9   -to hex5[3]
set_location_assignment  PIN_R5   -to hex5[4]
set_location_assignment  PIN_R4   -to hex5[5]
set_location_assignment  PIN_R3   -to hex5[6]
set_location_assignment  PIN_R2   -to hex6[0]
set_location_assignment  PIN_P4   -to hex6[1]
set_location_assignment  PIN_P3   -to hex6[2]
set_location_assignment  PIN_M2   -to hex6[3]
set_location_assignment  PIN_M3   -to hex6[4]
set_location_assignment  PIN_M5   -to hex6[5]
set_location_assignment  PIN_M4   -to hex6[6]
set_location_assignment  PIN_L3   -to hex7[0]
set_location_assignment  PIN_L2   -to hex7[1]
set_location_assignment  PIN_L9   -to hex7[2]
set_location_assignment  PIN_L6   -to hex7[3]
set_location_assignment  PIN_L7   -to hex7[4]
set_location_assignment  PIN_P9   -to hex7[5]
set_location_assignment  PIN_N9   -to hex7[6]
