
.DEFAULT: main.si
	rm -rf BUILD_$@
	silice-make.py -s main.si -b $@ -p basic,uart -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
