
.DEFAULT: sdram_test.si
		silice-make.sh -s sdram_test.si -b $@ -p basic,sdram -o BUILD_$(subst :,_,$@) $(ARGS)

icarus: sdram_test.si
		silice-make.sh -s sdram_test.si -b $@ -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
