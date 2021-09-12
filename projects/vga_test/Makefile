
.DEFAULT: vga_test.ice
		silice-make.py -s vga_test.ice -b $@ -p basic,vga -o BUILD_$(subst :,_,$@) $(ARGS)

icarus:
		silice-make.py -s vga_test.ice -b $@ -p basic,vga,top_only -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*
