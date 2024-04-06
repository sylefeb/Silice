
.DEFAULT: wolfpga.si
		silice-make.py -s wolfpga.si -b $@ -p basic,vga,sdram -o BUILD_$(subst :,_,$@) $(ARGS)

icarus: wolfpga.si
		silice-make.py -s wolfpga.si -b $@ -p basic,vga -o BUILD_$(subst :,_,$@) $(ARGS)

ulx3s colorlight: wolfpga.si
		silice-make.py -s wolfpga.si -b $@ -p basic,hdmi,sdram -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
