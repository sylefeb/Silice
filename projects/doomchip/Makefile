
.DEFAULT: vga_doomchip.ice
		silice-make.py -s vga_doomchip.ice -b $@ -p basic,vga,sdram -o BUILD_$(subst :,_,$@)

icarus: vga_doomchip.ice
		silice-make.py -s vga_doomchip.ice -b $@ -p basic,vga -o BUILD_$(subst :,_,$@)

# For the ulx3s we use the shell script (-t shell) that has additional options to yosys (scratchpad for abc9)
# For now it does not seem possible to add this option through Edalize
ulx3s: hdmi_doomchip.ice
		silice-make.py -s hdmi_doomchip.ice -b $@ -p basic,hdmi,sdram,buttons -o BUILD_$(subst :,_,$@) -t shell

de10nano: vga_doomchip.ice
		silice-make.py -s vga_doomchip.ice -b $@ -p basic,vga,sdram,keypad -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*
