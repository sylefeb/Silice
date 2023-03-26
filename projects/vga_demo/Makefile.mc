
.DEFAULT: vga_mc.si
		silice-make.py -s vga_mc.si -b $@ -p basic,vga -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
