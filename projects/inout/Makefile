
.DEFAULT: inout.si
		silice-make.py -s inout.si -b $@ -p basic,pmod -a split-inouts -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
