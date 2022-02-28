
.DEFAULT: oled_text.si
		silice-make.py -s oled_text.si -b $@ -p basic,oled -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
