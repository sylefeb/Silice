
.DEFAULT: oled_sdcard_test.ice
		silice-make.py -s oled_sdcard_test.ice -b $@ -p basic,oled,sdcard,buttons -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
