
.DEFAULT: vga_test.si
		silice-make.sh -s vga_test.si -b $@ -p basic,vga -o BUILD_$(subst :,_,$@) $(ARGS)

icarus:
		silice-make.sh -s vga_test.si -b $@ -p basic,vga,top_only -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*
