
.DEFAULT: hdmi_test.ice
		silice-make.py -s hdmi_test.ice -b $@ -p basic,hdmi -DCLOCK_25MHz=1 -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
