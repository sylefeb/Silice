
.DEFAULT: wolfpga.ice
		silice-make.py -s wolfpga.ice -b $@ -p basic,vga,sdram -o BUILD_$(subst :,_,$@) $(ARGS)

icarus: wolfpga.ice
		silice-make.py -s wolfpga.ice -b $@ -p basic,vga -o BUILD_$(subst :,_,$@) $(ARGS)

ulx3s: wolfpga.ice
		silice-make.py -s wolfpga.ice -b $@ -p basic,hdmi,sdram -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
