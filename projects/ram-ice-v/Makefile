
.DEFAULT: video_rv32i.ice
ifdef tool
		silice-make.py -s video_rv32i.ice -b $@ -p basic,sdram,hdmi,sdcard -o BUILD_$(subst :,_,$@) -t $(tool)
else
		silice-make.py -s video_rv32i.ice -b $@ -p basic,sdram,hdmi,sdcard -o BUILD_$(subst :,_,$@)
endif

ulx3s: video_rv32i.ice
		silice-make.py -s video_rv32i.ice -b $@ -p basic,sdram,hdmi,sdcard -o BUILD_$(subst :,_,$@) -t shell

verilator: video_rv32i.ice
		silice-make.py -s video_rv32i.ice -b $@ -p basic,vga,sdram -o BUILD_$(subst :,_,$@)

icarus: video_rv32i.ice
		silice-make.py -s video_rv32i.ice -b $@ -p basic,vga -o BUILD_$(subst :,_,$@)

sdcard: make_sdcard.ice
		silice-make.py -s make_sdcard.ice -b verilator -p basic,vga,sdram -o BUILD_$(subst :,_,$@)

font: make_font.ice
		silice-make.py -s make_font.ice -b verilator -p basic,vga,sdram -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*
