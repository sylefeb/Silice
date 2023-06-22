
.DEFAULT: main.si
	rm -rf BUILD_$@
	silice-make.py -s main.si -b $@ -p basic,pmod,uart -o BUILD_$(subst :,_,$@) $(ARGS)

ulx3s: main_x4.si
	rm -rf BUILD_$@
	silice-make.py -s main_x4.si -b $@ -p basic,gpio,uart -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: main.si
	rm -rf BUILD_$@
	silice-make.py -s main.si -b $@ -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
