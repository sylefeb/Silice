
.DEFAULT: sdram_memtest.si
		silice-make.sh -s sdram_memtest.si -b $@ -p basic,sdram -o BUILD_$(subst :,_,$@) $(ARGS)

icarus: sdram_memtest.si
		silice-make.sh -s sdram_memtest.si -b $@ -p basic -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*
