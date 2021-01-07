
.DEFAULT: video_rv32i.ice
ifdef tool
		silice-make.py -s video_rv32i.ice -b $@ -p basic,sdram,hdmi,sdcard -o BUILD_$(subst :,_,$@) -t $(tool)
else
		silice-make.py -s video_rv32i.ice -b $@ -p basic,sdram,hdmi,sdcard -o BUILD_$(subst :,_,$@)
endif

verilator: video_rv32i.ice
		silice-make.py -s video_rv32i.ice -b $@ -p basic,vga,sdram -o BUILD_$(subst :,_,$@)

sdcard: make_sdcard.ice
		silice-make.py -s make_sdcard.ice -b verilator -p basic,vga,sdram -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*
