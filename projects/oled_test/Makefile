.DEFAULT: oled_test.ice
		silice-make.py -s oled_test.ice -b $@ -p basic,oled -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*
