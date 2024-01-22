
.DEFAULT: vga_humanshader.si
		silice-make.py -s vga_humanshader.si -b $@ -p basic,vga -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
