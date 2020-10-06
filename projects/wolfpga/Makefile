
.DEFAULT: wolfpga.ice
		silice-make.py -s wolfpga.ice -b $@ -p basic,vga,sdram -o BUILD_$(subst :,_,$@)

icarus: wolfpga.ice
		silice-make.py -s wolfpga.ice -b $@ -p basic,vga -o BUILD_$(subst :,_,$@)

ulx3s: wolfpga.ice
		silice-make.py -s wolfpga.ice -b $@ -p basic,hdmi,sdram -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*
