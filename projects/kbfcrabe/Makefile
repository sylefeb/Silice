
.DEFAULT: main.si
	rm -rf BUILD_$@
	silice-make.sh -s main.si -b $@ -p basic,feather -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: main.si
	rm -rf BUILD_$@
	silice-make.sh -s main.si -b $@ -p basic,oled -o BUILD_$(subst :,_,$@) $(ARGS)

icarus: main.si
	silice-make.sh -s main.si -b $@ -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
