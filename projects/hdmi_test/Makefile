
.DEFAULT: hdmi_test.si
		silice-make.sh -s hdmi_test.si -b $@ -p basic,hdmi -DCLOCK_25MHz=1 -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
