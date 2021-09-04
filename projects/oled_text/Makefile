
.DEFAULT: oled_text.ice
		silice-make.py -s oled_text.ice -b $@ -p basic,oled -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
