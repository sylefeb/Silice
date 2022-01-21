
.DEFAULT: main.ice
	rm -rf BUILD_$@
	silice-make.py -s main.ice -b $@ -p basic,pmod,uart -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: main.ice
	rm -rf BUILD_$@
	silice-make.py -s main.ice -b $@ -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
