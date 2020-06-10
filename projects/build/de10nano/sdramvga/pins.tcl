#============================================================
# Clocks
#============================================================

# set_location_assignment PIN_V11 -to clk
# set_location_assignment PIN_E11 -to clk
set_location_assignment PIN_Y13 -to clk
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to clk

#============================================================
# LEDs
#============================================================

set_location_assignment PIN_W15  -to led[0]
set_location_assignment PIN_AA24 -to led[1]
set_location_assignment PIN_V16  -to led[2]
set_location_assignment PIN_V15  -to led[3]
set_location_assignment PIN_AF26 -to led[4]
set_location_assignment PIN_AE26 -to led[5]
set_location_assignment PIN_Y16  -to led[6]
set_location_assignment PIN_AA23 -to led[7]

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to led*

#============================================================
# Keypad
#============================================================

set_location_assignment PIN_AE20 -to kpadC[0]
set_location_assignment PIN_AF20 -to kpadC[1]
set_location_assignment PIN_AH18 -to kpadC[2]
set_location_assignment PIN_AH19 -to kpadC[3]
set_location_assignment PIN_AG15 -to kpadR[0]
set_location_assignment PIN_AF18 -to kpadR[1]
set_location_assignment PIN_AG18 -to kpadR[2]
set_location_assignment PIN_AG19 -to kpadR[3]

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to kpadC*
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to kpadR*
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to kpadR*

#============================================================
# LCD1602
#============================================================

set_location_assignment PIN_AG9  -to lcd_rs
set_location_assignment PIN_U14  -to lcd_rw
set_location_assignment PIN_U13  -to lcd_e
set_location_assignment PIN_AF27 -to lcd_d[0]
set_location_assignment PIN_AH27 -to lcd_d[1]
set_location_assignment PIN_AE25 -to lcd_d[2]
set_location_assignment PIN_AG26 -to lcd_d[3]
set_location_assignment PIN_AH26 -to lcd_d[4]
set_location_assignment PIN_AF25 -to lcd_d[5]
set_location_assignment PIN_AG25 -to lcd_d[6]
set_location_assignment PIN_AH24 -to lcd_d[7]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to lcd_*

#============================================================
# SSD1351
#============================================================

set_location_assignment PIN_AG8  -to oled_din
set_location_assignment PIN_AH8  -to oled_clk
set_location_assignment PIN_AF17 -to oled_cs
set_location_assignment PIN_AE15 -to oled_dc
set_location_assignment PIN_AF15 -to oled_rst
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to oled_*

#============================================================
# VGA
#============================================================

set_location_assignment PIN_AE19 -to vga_hs
set_location_assignment PIN_AE17 -to vga_vs
set_location_assignment PIN_AG28 -to vga_r[5]
set_location_assignment PIN_AA15 -to vga_r[4]
set_location_assignment PIN_Y15  -to vga_r[3]
set_location_assignment PIN_AC24 -to vga_r[2]
set_location_assignment PIN_AD26 -to vga_r[1]
set_location_assignment PIN_AF28 -to vga_r[0]
set_location_assignment PIN_AF21 -to vga_g[5]
set_location_assignment PIN_AE22 -to vga_g[4]
set_location_assignment PIN_AA20 -to vga_g[3]
set_location_assignment PIN_AG21 -to vga_g[2]
set_location_assignment PIN_AH22 -to vga_g[1]
set_location_assignment PIN_AF23 -to vga_g[0]
set_location_assignment PIN_AG20 -to vga_b[5]
set_location_assignment PIN_AF22 -to vga_b[4]
set_location_assignment PIN_AH23 -to vga_b[3]
set_location_assignment PIN_AH21 -to vga_b[2]
set_location_assignment PIN_AG24 -to vga_b[1]
set_location_assignment PIN_AG23 -to vga_b[0]

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to vga_*
set_instance_assignment -name CURRENT_STRENGTH_NEW "MAXIMUM CURRENT" -to vga_*
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to vga_*

#============================================================
# SDRAM
#============================================================

set_location_assignment PIN_Y11 -to SDRAM_A[0]
set_location_assignment PIN_AA26 -to SDRAM_A[1]
set_location_assignment PIN_AA13 -to SDRAM_A[2]
set_location_assignment PIN_AA11 -to SDRAM_A[3]
set_location_assignment PIN_W11 -to SDRAM_A[4]
set_location_assignment PIN_Y19 -to SDRAM_A[5]
set_location_assignment PIN_AB23 -to SDRAM_A[6]
set_location_assignment PIN_AC23 -to SDRAM_A[7]
set_location_assignment PIN_AC22 -to SDRAM_A[8]
set_location_assignment PIN_C12 -to SDRAM_A[9]
set_location_assignment PIN_AB26 -to SDRAM_A[10]
set_location_assignment PIN_AD17 -to SDRAM_A[11]
set_location_assignment PIN_D12 -to SDRAM_A[12]
set_location_assignment PIN_Y17 -to SDRAM_BA[0]
set_location_assignment PIN_AB25 -to SDRAM_BA[1]
set_location_assignment PIN_E8 -to SDRAM_DQ[0]
set_location_assignment PIN_V12 -to SDRAM_DQ[1]
set_location_assignment PIN_D11 -to SDRAM_DQ[2]
set_location_assignment PIN_W12 -to SDRAM_DQ[3]
set_location_assignment PIN_AH13 -to SDRAM_DQ[4]
set_location_assignment PIN_D8 -to SDRAM_DQ[5]
set_location_assignment PIN_AH14 -to SDRAM_DQ[6]
set_location_assignment PIN_AF7 -to SDRAM_DQ[7]
set_location_assignment PIN_AE24 -to SDRAM_DQ[8]
set_location_assignment PIN_AD23 -to SDRAM_DQ[9]
set_location_assignment PIN_AE6 -to SDRAM_DQ[10]
set_location_assignment PIN_AE23 -to SDRAM_DQ[11]
set_location_assignment PIN_AG14 -to SDRAM_DQ[12]
set_location_assignment PIN_AD5 -to SDRAM_DQ[13]
set_location_assignment PIN_AF4 -to SDRAM_DQ[14]
set_location_assignment PIN_AH3 -to SDRAM_DQ[15]
set_location_assignment PIN_AG13 -to SDRAM_DQML
set_location_assignment PIN_AF13 -to SDRAM_DQMH
set_location_assignment PIN_AD20 -to SDRAM_CLK
set_location_assignment PIN_AG10 -to SDRAM_CKE
set_location_assignment PIN_AA19 -to SDRAM_nWE
set_location_assignment PIN_AA18 -to SDRAM_nCAS
set_location_assignment PIN_Y18 -to SDRAM_nCS
set_location_assignment PIN_W14 -to SDRAM_nRAS

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_*
set_instance_assignment -name CURRENT_STRENGTH_NEW "MAXIMUM CURRENT" -to SDRAM_*
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to SDRAM_*
set_instance_assignment -name FAST_OUTPUT_ENABLE_REGISTER ON -to SDRAM_DQ[*]
set_instance_assignment -name FAST_INPUT_REGISTER ON -to SDRAM_DQ[*]
set_instance_assignment -name ALLOW_SYNCH_CTRL_USAGE OFF -to *|SDRAM_*
