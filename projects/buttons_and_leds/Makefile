
.DEFAULT: buttons_and_leds.ice
ifdef tool
		silice-make.py -s buttons_and_leds.ice -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@) -t $(tool)
else
		silice-make.py -s buttons_and_leds.ice -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@)
endif

clean:
	rm -rf BUILD_*
