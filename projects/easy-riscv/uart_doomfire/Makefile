
.DEFAULT: main.ice
	rm -rf BUILD_$@
	silice-make.py -s main.ice -b $@ -p basic,uart -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
