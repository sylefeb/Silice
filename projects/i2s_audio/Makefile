
.DEFAULT: main.ice
		silice-make.py -s main.ice -b $@ -p basic,pmod -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: main.ice
		silice-make.py -s main.ice -b $@ -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
