
.DEFAULT: with_ice-v-dual.si
	rm -rf BUILD_$@
	silice-make.sh -s with_ice-v-dual.si -b $@ -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
