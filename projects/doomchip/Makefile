
.DEFAULT: vga_doomchip.ice
		silice-make.py -s vga_doomchip.ice -b $@ -p basic,vga,sdram -o BUILD_$(subst :,_,$@) $(ARGS)

icarus: vga_doomchip.ice
		silice-make.py -s vga_doomchip.ice -b $@ -p basic,vga -o BUILD_$(subst :,_,$@)  $(ARGS)

# For the ulx3s we use the shell script (-t shell) that has additional options to yosys (scratchpad for abc9)
# TODO add this option through Edalize
ulx3s: hdmi_doomchip.ice
		silice-make.py -s hdmi_doomchip.ice -b $@ -p basic,hdmi,sdram,buttons -o BUILD_$(subst :,_,$@) -t shell $(ARGS)

ulx3s-oled: oled_doomchip.ice
		silice-make.py -s oled_doomchip.ice -b ulx3s -p basic,oled,buttons -o BUILD_$(subst :,_,$@) -t shell $(ARGS)

de10nano: vga_doomchip.ice
		silice-make.py -s vga_doomchip.ice -b $@ -p basic,vga,sdram,buttons -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
