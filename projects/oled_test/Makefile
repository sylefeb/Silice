
.DEFAULT: oled_test.ice
ifdef tool
		silice-make.py -s oled_test.ice -b $@ -p basic,oled -o BUILD_$(subst :,_,$@) -t $(tool)
else
		silice-make.py -s oled_test.ice -b $@ -p basic,oled -o BUILD_$(subst :,_,$@)
endif

clean:
	rm -rf BUILD_*
