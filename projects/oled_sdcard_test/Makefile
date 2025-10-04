
.DEFAULT: oled_sdcard_test.si
		silice-make.sh -s oled_sdcard_test.si -b $@ -p basic,oled,sdcard,buttons -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
