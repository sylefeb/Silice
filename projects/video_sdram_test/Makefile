
.DEFAULT: video_sdram_test.ice
		silice-make.py -s video_sdram_test.ice -b $@ -p basic,vga,sdram -o BUILD_$(subst :,_,$@)

# For the ulx3s we use the shell script (-t shell) that has additional options to yosys (scratchpad for abc9)
ulx3s: video_sdram_test.ice
		silice-make.py -s video_sdram_test.ice -b $@ -p basic,hdmi,sdram -o BUILD_$(subst :,_,$@) -t shell

icarus: video_sdram_test.ice
		silice-make.py -s video_sdram_test.ice -b $@ -p basic,vga,top_only -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*
