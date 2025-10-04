
.DEFAULT: video_sdram_test.si
		silice-make.sh -s video_sdram_test.si -b $@ -p basic,vga,sdram -o BUILD_$(subst :,_,$@) $(ARGS)

yowasp-%:
		silice-make.sh -s video_sdram_test.si -b $(subst yowasp-,,$@) -p basic,hdmi,sdram -t yowasp -o BUILD_$(subst :,_,$@) $(ARGS)

# For the ulx3s we use the shell script (-t shell) that has additional options to yosys (scratchpad for abc9)
ulx3s: video_sdram_test.si
		silice-make.sh -s video_sdram_test.si -b $@ -p basic,hdmi,sdram -o BUILD_$(subst :,_,$@) -t shell $(ARGS)

colorlight: video_sdram_test.si
		silice-make.sh -s video_sdram_test.si -b $@ -p basic,hdmi,sdram -o BUILD_$(subst :,_,$@) $(ARGS)

icarus: video_sdram_test.si
		silice-make.sh -s video_sdram_test.si -b $@ -p basic,vga -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
