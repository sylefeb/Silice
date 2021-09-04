
.DEFAULT: $@.ice.lpp
		silice-make.py -s $@.ice -b verilator -p basic -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*
