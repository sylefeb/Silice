file ?= t1.si

.DEFAULT: $(file)
		silice-make.py -s $(file) -b $@ -p basic -o BUILD_$(subst :,_,$@)

icestick:
ifeq ($(file),t14.si)
		silice-make.py -s $(file) -b $@ -p basic,pmod -o BUILD_icestick
else
		silice-make.py -s $(file) -b $@ -p basic -o BUILD_icestick
endif

clean:
	rm -rf BUILD_*
