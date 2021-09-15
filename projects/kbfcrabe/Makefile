
.DEFAULT: main.ice
	rm -rf BUILD_$@
	silice-make.py -s main.ice -b $@ -p basic,feather -o BUILD_$(subst :,_,$@) $(ARGS)

ulx3s: main.ice
	rm -rf BUILD_$@
	silice-make.py -s main.ice -b $@ -p basic,oled -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: main.ice
	rm -rf BUILD_$@
	silice-make.py -s main.ice -b $@ -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
