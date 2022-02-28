.DEFAULT: oled_test.si
		silice-make.py -s oled_test.si -b $@ -p basic,oled -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: oled_test.si
		silice-make.py -s oled_test.si -b $@ -p basic,oled -o BUILD_$(subst :,_,$@) $(ARGS)

icarus: oled_test.si
		silice-make.py -s oled_test.si -b $@ -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
