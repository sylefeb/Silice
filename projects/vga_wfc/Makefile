
.DEFAULT: vga_wfc_basic.si
		silice-make.py -s vga_wfc_basic.si -b $@ -p basic,vga,buttons -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: vga_wfc_basic.si
	silice-make.py -s vga_wfc_basic.si -b $@ -p basic,vga -o BUILD_$(subst :,_,$@)

icarus: vga_wfc_basic.si
	silice-make.py -s vga_wfc_basic.si -b $@ -p basic,vga -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*
