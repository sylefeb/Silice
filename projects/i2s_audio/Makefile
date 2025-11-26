
.DEFAULT: main.si
		silice-make.sh -s main.si -b $@ -p basic,pmod -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: main.si
		silice-make.sh -s main.si -b $@ -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
