
.DEFAULT: hdmi_test.ice
ifdef tool
		silice-make.py -s hdmi_test.ice -b $@ -p basic,hdmi -o BUILD_$(subst :,_,$@) -t $(tool)
else
		silice-make.py -s hdmi_test.ice -b $@ -p basic,hdmi -o BUILD_$(subst :,_,$@)
endif

clean:
	rm -rf BUILD_*
