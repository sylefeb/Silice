
.DEFAULT: vga_test.ice
ifdef tool
		silice-make.py -s vga_test.ice -b $@ -p basic,vga -o BUILD_$(subst :,_,$@) -t $(tool)
else
		silice-make.py -s vga_test.ice -b $@ -p basic,vga -o BUILD_$(subst :,_,$@)
endif

icarus:
		silice-make.py -s vga_test.ice -b $@ -p basic,vga,top_only -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*
