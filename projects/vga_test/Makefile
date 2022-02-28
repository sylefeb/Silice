
.DEFAULT: vga_test.si
		silice-make.py -s vga_test.si -b $@ -p basic,vga -o BUILD_$(subst :,_,$@) $(ARGS)

icarus:
		silice-make.py -s vga_test.si -b $@ -p basic,vga,top_only -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*
