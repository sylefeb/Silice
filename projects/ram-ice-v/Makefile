
.DEFAULT: video_rv32i.ice
		silice-make.py -s video_rv32i.ice -b $@ -p basic,sdram,hdmi,sdcard -o BUILD_$(subst :,_,$@)

verilator: video_rv32i.ice
		silice-make.py -s video_rv32i.ice -b $@ -p basic,vga,sdram -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*
