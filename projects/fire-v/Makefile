
.DEFAULT: wildfire.si
		silice-make.py -s wildfire.si -b $@ -p basic,sdram,hdmi,sdcard -o BUILD_$(subst :,_,$@) $(ARGS)

ulx3s: wildfire.si
		silice-make.py -s wildfire.si -b $@ -p basic,sdram,hdmi,sdcard -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: wildfire.si
		silice-make.py -s wildfire.si -b $@ -p basic,vga,sdram -o BUILD_$(subst :,_,$@) $(ARGS)

icarus: wildfire.si
		silice-make.py -s wildfire.si -b $@ -p basic,vga -o BUILD_$(subst :,_,$@) $(ARGS)

spiflash: make_sdcard.si
		silice-make.py -s make_sdcard.si -b verilator -p basic,vga,sdram -o BUILD_$(subst :,_,$@) $(ARGS)

sdcard: make_sdcard.si
		silice-make.py -s make_sdcard.si -b verilator -p basic,vga,sdram -o BUILD_$(subst :,_,$@) $(ARGS)


font: make_font.si
		silice-make.py -s make_font.si -b verilator -p basic,vga,sdram -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
