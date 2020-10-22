
.DEFAULT: oled_sdcard_test.ice
ifdef tool
		silice-make.py -s oled_sdcard_test.ice -b $@ -p basic,oled,sdcard,buttons -o BUILD_$(subst :,_,$@) -t $(tool)
else
		silice-make.py -s oled_sdcard_test.ice -b $@ -p basic,oled,sdcard,buttons -o BUILD_$(subst :,_,$@)
endif

clean:
	rm -rf BUILD_*
