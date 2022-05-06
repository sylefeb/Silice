
.DEFAULT: with_ice-v-dual.si
	rm -rf BUILD_$@
	silice-make.py -s with_ice-v-dual.si -b $@ -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
