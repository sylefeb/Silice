
.DEFAULT: vga_doomchip.si
		silice-make.sh -s vga_doomchip.si -b $@ -p basic,vga,sdram -o BUILD_$(subst :,_,$@) $(ARGS)

icarus: vga_doomchip.si
		silice-make.sh -s vga_doomchip.si -b $@ -p basic,vga -o BUILD_$(subst :,_,$@)  $(ARGS)

# For the ulx3s we use the shell script (-t shell) that has additional options to yosys (scratchpad for abc9)
# TODO add this option through Edalize
ulx3s: hdmi_doomchip.si
		silice-make.sh -s hdmi_doomchip.si -b $@ -p basic,hdmi,sdram,buttons -o BUILD_$(subst :,_,$@) -t shell $(ARGS)

ulx3s-oled: oled_doomchip.si
		silice-make.sh -s oled_doomchip.si -b ulx3s -p basic,oled,buttons -o BUILD_$(subst :,_,$@) -t shell $(ARGS)

de10nano: vga_doomchip.si
		silice-make.sh -s vga_doomchip.si -b $@ -p basic,vga,sdram,buttons -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
