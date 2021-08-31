
.DEFAULT: sdram_test.ice
		silice-make.py -s sdram_test.ice -b $@ -p basic,sdram -o BUILD_$(subst :,_,$@) $(ARGS)

icarus: sdram_test.ice
		silice-make.py -s sdram_test.ice -b $@ -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
