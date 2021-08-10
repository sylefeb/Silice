
.DEFAULT: hdmi_test.ice
		silice-make.py -s hdmi_test.ice -b $@ -p basic,hdmi -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
