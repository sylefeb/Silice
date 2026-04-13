
.DEFAULT: vga_wfc_basic.si
		silice-make.sh -s vga_wfc_basic.si -b $@ -p basic,vga,buttons -o BUILD_$(subst :,_,$@) $(ARGS)

gatemate_evb: vga_wfc_basic.si
	silice-make.sh -s vga_wfc_basic.si -b $@ -p basic,vga -o BUILD_$(subst :,_,$@)

gatemate_evb2: vga_wfc_basic.si
	silice-make.sh -s vga_wfc_basic.si -b gatemate_evb -p basic,vga -o BUILD_$(subst :,_,$@)

verilator: vga_wfc_basic.si
	silice-make.sh -s vga_wfc_basic.si -b $@ -p basic,vga -o BUILD_$(subst :,_,$@)

icarus: vga_wfc_basic.si
	silice-make.sh -s vga_wfc_basic.si -b $@ -p basic,vga -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*
