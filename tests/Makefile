
.DEFAULT: $@.si.lpp
		silice-make.py -s $@.si -b verilator -p basic -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*
