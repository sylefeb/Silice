
.DEFAULT: main.si
	rm -rf BUILD_$@
	silice-make.py -s main.si -b $@ -p basic,pmod -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: main.si
	rm -rf BUILD_$@
	silice-make.py -s main.si -b $@ -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
