file ?= step1.si

.DEFAULT: $(file)
		silice-make.py -s $(file) -b $@ -p basic -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*
