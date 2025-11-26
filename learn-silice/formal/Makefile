
.DEFAULT: $@.si.lpp
#		silice-make.sh -s $@.si -b verilator -p basic -o BUILD_$(subst :,_,$@)
		silice-make.sh -s $@.si -b formal -p basic -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*
