
.DEFAULT: buttons_and_leds.si
		silice-make.sh -s buttons_and_leds.si -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@)  $(ARGS)

clean:
	rm -rf BUILD_*
