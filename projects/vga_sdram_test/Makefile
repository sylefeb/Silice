
.DEFAULT: vga_sdram_test.ice
		silice-make.py -s vga_sdram_test.ice -b $@ -p basic,vga,sdram -o BUILD_$(subst :,_,$@)

icarus: vga_sdram_test.ice
		silice-make.py -s vga_sdram_test.ice -b $@ -p basic,vga -o BUILD_$(subst :,_,$@)

ulx3s: vga_sdram_test.ice
		silice-make.py -s vga_sdram_test.ice -b $@ -p basic,hdmi,sdram -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*
