
.DEFAULT: vga_rototexture.si
		silice-make.sh -s vga_rototexture.si -b $@ -p basic,vga -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
