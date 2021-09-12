
.DEFAULT: vga_rototexture.ice
		silice-make.py -s vga_rototexture.ice -b $@ -p basic,vga -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
