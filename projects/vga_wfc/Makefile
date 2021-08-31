
.DEFAULT: vga_wfc_basic.ice
		silice-make.py -s vga_wfc_basic.ice -b $@ -p basic,vga,buttons -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: vga_wfc_basic.ice
	silice-make.py -s vga_wfc_basic.ice -b $@ -p basic,vga -o BUILD_$(subst :,_,$@)

icarus: vga_wfc_basic.ice
	silice-make.py -s vga_wfc_basic.ice -b $@ -p basic,vga -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*
