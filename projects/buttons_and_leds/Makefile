
.DEFAULT: buttons_and_leds.ice
		silice-make.py -s buttons_and_leds.ice -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@)  $(ARGS)

clean:
	rm -rf BUILD_*
