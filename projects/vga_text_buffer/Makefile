
.DEFAULT: vga_text_buffer.ice
		silice-make.py -s vga_text_buffer.ice -b $@ -p basic,vga -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
