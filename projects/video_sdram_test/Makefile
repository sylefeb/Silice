
.DEFAULT: video_sdram_test.ice
		silice-make.py -s video_sdram_test.ice -b $@ -p basic,vga,sdram -o BUILD_$(subst :,_,$@)

icarus: video_sdram_test.ice
		silice-make.py -s video_sdram_test.ice -b $@ -p basic,vga -o BUILD_$(subst :,_,$@)

# For the ulx3s we use the shell script (-t shell) that has additional options to yosys (scratchpad for abc9)
# For now it does not seem possible to add this option through Edalize
ulx3s: video_sdram_test.ice
		silice-make.py -s video_sdram_test.ice -b $@ -p basic,hdmi,sdram -o BUILD_$(subst :,_,$@) -t shell

clean:
	rm -rf BUILD_*
