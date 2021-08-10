
.DEFAULT: wildfire.ice
		silice-make.py -s wildfire.ice -b $@ -p basic,sdram,hdmi,sdcard -o BUILD_$(subst :,_,$@)  $(ARGS)

ulx3s: wildfire.ice
		silice-make.py -s wildfire.ice -b $@ -p basic,sdram,hdmi,sdcard -o BUILD_$(subst :,_,$@) -t shell $(ARGS)

verilator: wildfire.ice
		silice-make.py -s wildfire.ice -b $@ -p basic,vga,sdram -o BUILD_$(subst :,_,$@) $(ARGS)

icarus: wildfire.ice
		silice-make.py -s wildfire.ice -b $@ -p basic,vga -o BUILD_$(subst :,_,$@) $(ARGS)

spiflash: make_sdcard.ice
		silice-make.py -s make_sdcard.ice -b verilator -p basic,vga,sdram -o BUILD_$(subst :,_,$@) $(ARGS)

sdcard: make_sdcard.ice
		silice-make.py -s make_sdcard.ice -b verilator -p basic,vga,sdram -o BUILD_$(subst :,_,$@) $(ARGS)


font: make_font.ice
		silice-make.py -s make_font.ice -b verilator -p basic,vga,sdram -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
