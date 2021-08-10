
.DEFAULT: inout.ice
		silice-make.py -s inout.ice -b $@ -p basic,pmod -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
