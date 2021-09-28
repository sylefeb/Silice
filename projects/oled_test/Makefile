.DEFAULT: oled_test.ice
		silice-make.py -s oled_test.ice -b $@ -p basic,oled -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: oled_test.ice
		silice-make.py -s oled_test.ice -b $@ -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

icarus: oled_test.ice
		silice-make.py -s oled_test.ice -b $@ -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
