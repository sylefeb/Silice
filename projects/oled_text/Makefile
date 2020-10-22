
.DEFAULT: oled_text.ice
ifdef tool
		silice-make.py -s oled_text.ice -b $@ -p basic,oled -o BUILD_$(subst :,_,$@) -t $(tool)
else
		silice-make.py -s oled_text.ice -b $@ -p basic,oled -o BUILD_$(subst :,_,$@)
endif

clean:
	rm -rf BUILD_*
