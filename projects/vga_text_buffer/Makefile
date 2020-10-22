
.DEFAULT: vga_text_buffer.ice
ifdef tool
		silice-make.py -s vga_text_buffer.ice -b $@ -p basic,vga -o BUILD_$(subst :,_,$@) -t $(tool)
else
		silice-make.py -s vga_text_buffer.ice -b $@ -p basic,vga -o BUILD_$(subst :,_,$@)
endif

clean:
	rm -rf BUILD_*
