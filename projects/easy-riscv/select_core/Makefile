
.DEFAULT: with_ice-v-dual.ice
	rm -rf BUILD_$@
	silice-make.py -s with_ice-v-dual.ice -b $@ -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
