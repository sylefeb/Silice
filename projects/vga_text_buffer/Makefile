
.DEFAULT: vga_text_buffer.si
		silice-make.sh -s vga_text_buffer.si -b $@ -p basic,vga -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
